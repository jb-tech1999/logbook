import Foundation
import CoreLocation
import SwiftData
import Combine
import ActivityKit

@MainActor
class TripTrackingService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isTracking: Bool = false
    @Published var currentTrip: Trip?
    @Published var currentSpeed: Double = 0
    @Published var distanceTraveled: Double = 0
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?
    private var lastLocation: CLLocation?
    private var lastSavedLocation: CLLocation? // Last location we saved to database
    private var recordingTimer: Timer?
    private var liveActivityUpdateTimer: Timer?
    private let minimumDistanceForPoint: Double = 5 // meters - only save if moved at least 5m
    private let recordingInterval: TimeInterval = 5 // seconds - check for updates every 5 seconds
    private let liveActivityUpdateInterval: TimeInterval = 2 // seconds - update live activity every 2 seconds
    private var currentActivity: Activity<TripLiveActivityAttributes>?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        // CRITICAL: delegate MUST be set BEFORE allowsBackgroundLocationUpdates
        // Otherwise the app will crash with abort() on iOS 14+
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .automotiveNavigation
        locationManager.distanceFilter = 5 // Update every 5 meters (more frequent for real-time feel)
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Only enable background updates if we have the required Info.plist key
        // This must be set AFTER delegate assignment
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            print("✅ Background location updates enabled")
        } else {
            print("⚠️ UIBackgroundModes not configured in Info.plist - background tracking disabled")
        }
    }
    
    // MARK: - Public Methods
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func startTracking(car: Car? = nil) {
        guard !isTracking else { return }
        guard let modelContext = modelContext else {
            print("⚠️ TripTrackingService: ModelContext not set")
            return
        }
        
        // Check and request authorization if needed
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            print("📍 Requesting location authorization...")
            locationManager.requestAlwaysAuthorization()
            // Will retry when authorization changes
            return
            
        case .denied, .restricted:
            print("❌ TripTrackingService: Location access denied or restricted")
            return
            
        case .authorizedWhenInUse:
            print("⚠️ TripTrackingService: Only 'When In Use' authorization - background tracking limited")
            // Continue anyway, but background tracking won't work optimally
            
        case .authorizedAlways:
            print("✅ TripTrackingService: Full location authorization granted")
            
        @unknown default:
            print("⚠️ TripTrackingService: Unknown authorization status")
            return
        }
        
        // Create new trip
        let trip = Trip(car: car)
        modelContext.insert(trip)
        
        do {
            try modelContext.save()
            currentTrip = trip
            isTracking = true
            distanceTraveled = 0
            lastLocation = nil
            lastSavedLocation = nil
            
            // Start location updates
            locationManager.startUpdatingLocation()
            
            // Start recording timer (saves points to database)
            startRecordingTimer()
            
            // Start live activity update timer (updates UI more frequently)
            startLiveActivityUpdateTimer()
            
            // Start Live Activity
            startLiveActivity(for: trip, car: car)
            
            print("✅ Trip tracking started - Trip ID: \(trip.persistentModelID)")
            print("   📍 Recording interval: \(recordingInterval)s")
            print("   🔄 Live update interval: \(liveActivityUpdateInterval)s")
        } catch {
            print("❌ Failed to create trip: \(error)")
        }
    }
    
    func stopTracking() {
        guard isTracking, let trip = currentTrip else { return }
        
        isTracking = false
        locationManager.stopUpdatingLocation()
        recordingTimer?.invalidate()
        recordingTimer = nil
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil
        
        // Finalize trip
        trip.endDate = Date()
        trip.isActive = false
        trip.totalDistance = distanceTraveled
        
        // Calculate average speed from all points
        if let points = trip.points, !points.isEmpty {
            let totalSpeed = points.reduce(0.0) { $0 + $1.speed }
            trip.averageSpeed = totalSpeed / Double(points.count)
        }
        
        do {
            try modelContext?.save()
            
            // End Live Activity
            endLiveActivity()
            
            print("✅ Trip tracking stopped - Distance: \(distanceTraveled)km, Duration: \(trip.durationFormatted)")
        } catch {
            print("❌ Failed to save trip: \(error)")
        }
        
        currentTrip = nil
        lastLocation = nil
    }
    
    // MARK: - Private Methods
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: recordingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordCurrentLocation()
            }
        }
    }
    
    private func startLiveActivityUpdateTimer() {
        liveActivityUpdateTimer = Timer.scheduledTimer(withTimeInterval: liveActivityUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLiveActivity()
            }
        }
    }
    
    private func recordCurrentLocation() {
        guard isTracking,
              let trip = currentTrip,
              let location = locationManager.location,
              let modelContext = modelContext else { return }
        
        // Check if we've moved enough distance since last SAVED point
        if let lastSaved = lastSavedLocation {
            let distance = location.distance(from: lastSaved)
            guard distance >= minimumDistanceForPoint else {
                // Not enough distance, but update UI metrics anyway
                print("⏭️ Skipping save - only \(String(format: "%.1f", distance))m from last point")
                return
            }
        }
        
        // Create trip point
        let point = TripPoint(from: location, trip: trip)
        modelContext.insert(point)
        
        // Update max speed
        let speedKmh = max(0, location.speed * 3.6)
        if speedKmh > trip.maxSpeed {
            trip.maxSpeed = speedKmh
        }
        
        lastSavedLocation = location
        
        do {
            try modelContext.save()
            print("💾 Point saved - Speed: \(String(format: "%.1f", speedKmh))km/h, Distance: \(String(format: "%.2f", distanceTraveled))km")
        } catch {
            print("❌ Failed to save trip point: \(error)")
        }
    }
    
    // MARK: - Live Activity Management
    
    private func startLiveActivity(for trip: Trip, car: Car?) {
        // Check iOS version (Live Activities require iOS 16.1+)
        guard #available(iOS 16.1, *) else {
            print("⚠️ Live Activities require iOS 16.1 or later")
            return
        }
        
        // Log authorization status (but don't block - iOS will prompt if needed)
        let authInfo = ActivityAuthorizationInfo()
        print("📊 Live Activity Authorization Status:")
        print("  - areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")
        print("  - frequentPushesEnabled: \(authInfo.frequentPushesEnabled)")
        
        // IMPORTANT: We must ALWAYS attempt to start the activity
        // iOS will show the permission prompt automatically on first launch
        // If user previously denied, the activity.request() will fail gracefully
        
        let attributes = TripLiveActivityAttributes(
            carMake: car?.make,
            carModel: car?.model,
            carYear: car?.year,
            tripStartDate: trip.startDate
        )
        
        let initialState = TripLiveActivityAttributes.ContentState(
            distanceTraveled: 0,
            currentSpeed: 0,
            duration: 0,
            startDate: trip.startDate,
            isActive: true
        )
        
        print("🚀 Requesting Live Activity...")
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("✅ Live Activity started successfully!")
            print("   Activity ID: \(activity.id)")
            print("   State: \(activity.activityState)")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
            print("   Error details: \(error.localizedDescription)")
            
            // Check if this is a permission issue
            if !authInfo.areActivitiesEnabled {
                print("   💡 Tip: User denied Live Activities permission")
                print("      Go to Settings → Logbook → Enable 'Live Activities'")
            }
        }
    }
    
    private func updateLiveActivity() {
        guard let activity = currentActivity,
              let trip = currentTrip else {
            print("⚠️ Cannot update Live Activity: activity=\(currentActivity != nil), trip=\(currentTrip != nil)")
            return
        }
        
        let duration = Date().timeIntervalSince(trip.startDate)
        
        let updatedState = TripLiveActivityAttributes.ContentState(
            distanceTraveled: distanceTraveled,
            currentSpeed: currentSpeed,
            duration: duration,
            startDate: trip.startDate,
            isActive: true
        )
        
        Task {
            do {
                await activity.update(.init(state: updatedState, staleDate: nil))
                print("📍 Live Activity updated - Distance: \(distanceTraveled)km, Speed: \(currentSpeed)km/h")
            } catch {
                print("❌ Failed to update Live Activity: \(error)")
            }
        }
    }
    
    private func endLiveActivity() {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to end")
            return
        }
        
        print("🛑 Ending Live Activity...")
        
        Task {
            let finalState = TripLiveActivityAttributes.ContentState(
                distanceTraveled: distanceTraveled,
                currentSpeed: 0,
                duration: currentTrip?.duration ?? 0,
                startDate: currentTrip?.startDate ?? Date(),
                isActive: false
            )
            
            do {
                await activity.end(
                    .init(state: finalState, staleDate: nil),
                    dismissalPolicy: .after(.now + 60) // Keep visible for 60 seconds
                )
                
                currentActivity = nil
                print("✅ Live Activity ended successfully")
                print("   Final distance: \(distanceTraveled)km")
                print("   Activity will dismiss in 60 seconds")
            } catch {
                print("❌ Failed to end Live Activity: \(error)")
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension TripTrackingService: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            // Update current speed for UI (real-time)
            let speedKmh = max(0, location.speed * 3.6) // Convert m/s to km/h
            self.currentSpeed = speedKmh
            
            // Update distance in real-time
            if let lastLoc = self.lastLocation {
                let segmentDistance = location.distance(from: lastLoc) / 1000.0 // Convert to km
                if segmentDistance > 0 && segmentDistance < 0.5 { // Sanity check: ignore jumps > 500m
                    self.distanceTraveled += segmentDistance
                }
            }
            
            self.lastLocation = location
            
            // Update trip's max speed if needed
            if let trip = self.currentTrip, speedKmh > trip.maxSpeed {
                trip.maxSpeed = speedKmh
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("📍 Location authorization changed: \(status.rawValue)")
        
        // If authorization was just granted and we should be tracking, start
        Task { @MainActor in
            if (status == .authorizedAlways || status == .authorizedWhenInUse) && self.currentTrip != nil && !self.isTracking {
                // Resume tracking if there's an active trip
                self.locationManager.startUpdatingLocation()
                self.startRecordingTimer()
            }
        }
    }
}

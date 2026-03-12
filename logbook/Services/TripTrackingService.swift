import Foundation
import CoreLocation
import SwiftData
import Observation
import ActivityKit
import OSLog

// MARK: - Logger (Apple Unified Logging — subsystem + category per WWDC guidance)
private let logger = Logger(subsystem: "com.jb-tech.logbook", category: "TripTracking")

@MainActor
@Observable
final class TripTrackingService: NSObject {

    // MARK: - Observable Properties
    var isTracking: Bool = false
    var currentTrip: Trip?
    var currentSpeed: Double = 0
    var distanceTraveled: Double = 0

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?
    private var lastLocation: CLLocation?
    private var lastSavedLocation: CLLocation?
    private var recordingTimer: Timer?
    private var liveActivityUpdateTimer: Timer?
    private let minimumDistanceForPoint: Double = 10 // meters - save points every 10m for smoother routes
    private let recordingInterval: TimeInterval = 2 // seconds - more frequent recording
    private let liveActivityUpdateInterval: TimeInterval = 1 // seconds - true real-time feel
    private var currentActivity: Activity<TripLiveActivityAttributes>?
    private var speedHistory: [Double] = [] // for smoothing speed readings

    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Deinitialization
    deinit {
        // deinit is nonisolated; avoid touching main-actor isolated state here.
        // Timers are invalidated explicitly during stopTracking and are weak-self based,
        // so deallocation remains safe without direct actor-isolated access in deinit.
    }

    // MARK: - Private Setup
    private func setupLocationManager() {
        // CRITICAL: delegate MUST be set BEFORE allowsBackgroundLocationUpdates
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.distanceFilter = 2 // meters - tighter for smooth real-time routes
        locationManager.pausesLocationUpdatesAutomatically = false

        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = true
            logger.info("Background location updates enabled")
        } else {
            logger.warning("UIBackgroundModes not configured — background tracking disabled")
        }
    }

    // MARK: - Public Interface
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func startTracking(car: Car? = nil) {
        guard !isTracking else { return }
        guard let modelContext else {
            logger.error("startTracking called but ModelContext is not set")
            return
        }

        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            logger.info("Requesting Always location authorization")
            locationManager.requestAlwaysAuthorization()
            return
        case .denied, .restricted:
            logger.error("Location access denied or restricted — cannot start tracking")
            return
        case .authorizedWhenInUse:
            logger.warning("Only 'When In Use' authorization — background tracking limited")
        case .authorizedAlways:
            logger.info("Full location authorization granted")
        @unknown default:
            logger.warning("Unknown authorization status \(status.rawValue) — aborting")
            return
        }

        let trip = Trip(car: car)
        modelContext.insert(trip)

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to create trip: \(error)")
            return
        }

        currentTrip = trip
        isTracking = true
        distanceTraveled = 0
        lastLocation = nil
        lastSavedLocation = nil
        speedHistory.removeAll()

        locationManager.startUpdatingLocation()
        startRecordingTimer()
        startLiveActivityUpdateTimer()
        startLiveActivity(for: trip, car: car)

        logger.info("Trip tracking started")
    }

    func stopTracking() {
        guard isTracking, let trip = currentTrip else {
            teardownTrackingState(resetTrip: false)
            return
        }

        isTracking = false
        locationManager.stopUpdatingLocation()
        invalidateTimers()

        trip.endDate = Date()
        trip.isActive = false
        trip.totalDistance = distanceTraveled

        if let points = trip.points, !points.isEmpty {
            let totalSpeed = points.reduce(0.0) { $0 + $1.speed }
            trip.averageSpeed = totalSpeed / Double(points.count)
        }

        do {
            try modelContext?.save()
        } catch {
            logger.error("Failed to save stopped trip: \(error)")
        }

        endLiveActivity()
        logger.info("Trip stopped — distance: \(self.distanceTraveled, format: .fixed(precision: 2)) km, duration: \(trip.durationFormatted)")

        teardownTrackingState(resetTrip: true)
    }

    /// Tears down timers, location updates, and transient tracking state.
    /// Keeps cleanup logic centralized so interruption paths don't leave timers running.
    private func teardownTrackingState(resetTrip: Bool) {
        locationManager.stopUpdatingLocation()
        invalidateTimers()
        currentSpeed = 0
        speedHistory.removeAll()

        if resetTrip {
            currentTrip = nil
            lastLocation = nil
            lastSavedLocation = nil
        }
    }

    // MARK: - Private Timer Helpers
    private func invalidateTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil
    }

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: recordingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recordCurrentLocation() }
        }
    }

    private func startLiveActivityUpdateTimer() {
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = Timer.scheduledTimer(withTimeInterval: liveActivityUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateLiveActivity() }
        }
    }

    // MARK: - Recording
    private func recordCurrentLocation() {
        guard isTracking,
              let trip = currentTrip,
              let location = locationManager.location,
              let modelContext else { return }

        if let lastSaved = lastSavedLocation {
            let distance = location.distance(from: lastSaved)
            guard distance >= minimumDistanceForPoint else { return }
        }

        let point = TripPoint(from: location, trip: trip)
        modelContext.insert(point)

        let speedKmh = max(0, location.speed * 3.6)
        if speedKmh > trip.maxSpeed { trip.maxSpeed = speedKmh }

        lastSavedLocation = location

        do {
            try modelContext.save()
            logger.debug("Point saved — speed: \(speedKmh, format: .fixed(precision: 1)) km/h, distance: \(self.distanceTraveled, format: .fixed(precision: 2)) km")
        } catch {
            logger.error("Failed to save trip point: \(error)")
        }
    }

    // MARK: - Live Activity
    private func startLiveActivity(for trip: Trip, car: Car?) {
        guard #available(iOS 16.1, *) else {
            logger.warning("Live Activities require iOS 16.1+")
            return
        }

        let authInfo = ActivityAuthorizationInfo()
        logger.info("Live Activity auth — enabled: \(authInfo.areActivitiesEnabled), frequentPushes: \(authInfo.frequentPushesEnabled)")

        let attributes = TripLiveActivityAttributes(
            carMake: car?.make, carModel: car?.model,
            carYear: car?.year, tripStartDate: trip.startDate
        )
        let initialState = TripLiveActivityAttributes.ContentState(
            distanceTraveled: 0, currentSpeed: 0, duration: 0,
            startDate: trip.startDate, isActive: true
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            logger.info("Live Activity started — ID: \(activity.id)")
        } catch {
            logger.error("Failed to start Live Activity: \(error)")
            if !authInfo.areActivitiesEnabled {
                logger.warning("User denied Live Activities — Settings → Logbook → Live Activities")
            }
        }
    }

    private func updateLiveActivity() {
        guard let activity = currentActivity, let trip = currentTrip else { return }

        let updatedState = TripLiveActivityAttributes.ContentState(
            distanceTraveled: distanceTraveled, currentSpeed: currentSpeed,
            duration: Date().timeIntervalSince(trip.startDate),
            startDate: trip.startDate, isActive: true
        )
        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = currentActivity else { return }
        Task {
            let finalState = TripLiveActivityAttributes.ContentState(
                distanceTraveled: distanceTraveled, currentSpeed: 0,
                duration: currentTrip?.duration ?? 0,
                startDate: currentTrip?.startDate ?? .now,
                isActive: false
            )
            await activity.end(.init(state: finalState, staleDate: nil),
                               dismissalPolicy: .after(.now + 60))
            currentActivity = nil
            logger.info("Live Activity ended — final distance: \(self.distanceTraveled, format: .fixed(precision: 2)) km")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension TripTrackingService: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Filter inaccurate readings per Apple's Core Location best practices
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 50 else { return }

        Task { @MainActor in
            let speedKmh = max(0, location.speed * 3.6)
            
            // Smooth speed using rolling average of last 5 readings
            self.speedHistory.append(speedKmh)
            if self.speedHistory.count > 5 {
                self.speedHistory.removeFirst()
            }
            let smoothedSpeed = self.speedHistory.reduce(0, +) / Double(self.speedHistory.count)
            self.currentSpeed = smoothedSpeed

            if let lastLoc = self.lastLocation {
                let segment = location.distance(from: lastLoc) / 1000.0
                // Tighter bounds for incremental distance to avoid GPS noise spikes
                if segment > 0 && segment < 0.1 { 
                    self.distanceTraveled += segment 
                }
            }
            self.lastLocation = location

            if let trip = self.currentTrip, smoothedSpeed > trip.maxSpeed {
                trip.maxSpeed = smoothedSpeed
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("CLLocationManager error: \(error)")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            logger.info("Location authorization changed: \(status.rawValue)")
            if (status == .authorizedAlways || status == .authorizedWhenInUse),
               self.currentTrip != nil, !self.isTracking {
                self.locationManager.startUpdatingLocation()
                self.startRecordingTimer()
            }
        }
    }
}

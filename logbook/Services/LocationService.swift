import CoreLocation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.jb-tech.logbook", category: "LocationService")

/// Centralized location manager — injected as an environment object from the app root.
/// Uses the Observation framework (@Observable) instead of ObservableObject per iOS 17+ best practices.
/// Follows Apple's Core Location guidance: never call startUpdatingLocation before authorization is granted.
@Observable
final class LocationManager: NSObject {

    // MARK: - Observable state
    var lastKnownLocation: CLLocationCoordinate2D?
    var speedKmh: Double = 0.0
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Private
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
        // Apple best practice: only request authorization here.
        // startUpdatingLocation is called in locationManagerDidChangeAuthorization
        // once the user grants permission — NOT here in init.
        authorizationStatus = manager.authorizationStatus

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .authorizedWhenInUse
                    || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            logger.info("Location updates started on init (already authorized)")
        }
    }

    /// Public compatibility API used by views that need to prompt for permission
    /// or restart location updates. This preserves the old call sites while still
    /// following Apple Core Location best practices.
    func checkLocationAuthorization() {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .notDetermined:
            logger.info("Requesting When In Use location authorization")
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            logger.info("Authorization already granted — starting location updates")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            logger.warning("Location authorization denied or restricted")
        @unknown default:
            logger.warning("Unknown authorization status: \(self.manager.authorizationStatus.rawValue)")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {

    /// Responds to authorization changes — the correct place to start location updates.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        logger.info("Authorization changed: \(manager.authorizationStatus.rawValue)")

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            logger.info("Location updates started after authorization granted")
        case .denied, .restricted:
            lastKnownLocation = nil
            logger.warning("Location access denied or restricted")
        case .notDetermined:
            logger.info("Authorization not yet determined")
        @unknown default:
            logger.warning("Unknown authorization status: \(self.manager.authorizationStatus.rawValue)")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Filter readings with poor accuracy per Apple Core Location best practices
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100 else { return }

        lastKnownLocation = location.coordinate
        speedKmh = location.speed >= 0 ? location.speed * 3.6 : 0
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location error: \(error)")
    }
}

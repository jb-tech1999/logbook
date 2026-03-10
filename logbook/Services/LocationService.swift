
import CoreLocation
import SwiftUI
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var lastKnownLocation: CLLocationCoordinate2D?
    @Published var speedKmh: Double = 0.0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func checkLocationAuthorization() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        lastKnownLocation = location.coordinate

        // speed is -1 when unavailable
        if location.speed >= 0 {
            speedKmh = location.speed * 3.6
        } else {
            speedKmh = 0
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }
}

import Foundation
import SwiftData
import CoreLocation

@Model
final class TripPoint {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var speed: Double // km/h
    var altitude: Double? // meters
    
    // Relationship — inverse is declared on Trip.points
    @Relationship var trip: Trip?
    
    init(
        timestamp: Date = .now,
        latitude: Double,
        longitude: Double,
        speed: Double,
        altitude: Double? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.altitude = altitude
    }
    
    // Convenience initializer from CLLocation
    convenience init(from location: CLLocation, trip: Trip? = nil) {
        self.init(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speed: max(0, location.speed * 3.6), // Convert m/s to km/h
            altitude: location.altitude
        )
        self.trip = trip
    }
    
    // Computed property to get CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

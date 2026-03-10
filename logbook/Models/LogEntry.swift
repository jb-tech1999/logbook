import Foundation
import SwiftData
import CoreLocation

@Model
final class LogEntry {
    var date: Date
    var speedometerKm: Double
    var distanceKm: Double
    var fuelLiters: Double
    var fuelSpend: Double
    var garageName: String?
    var garageSubtitle: String?
    var garageLatitude: Double?
    var garageLongitude: Double?
    var garageMapItemIdentifier: String?
    var createdAt: Date
    var user: User?
    var car: Car?

    init(
        date: Date = .now,
        speedometerKm: Double,
        distanceKm: Double,
        fuelLiters: Double,
        fuelSpend: Double,
        garageName: String? = nil,
        garageSubtitle: String? = nil,
        garageLatitude: Double? = nil,
        garageLongitude: Double? = nil,
        garageMapItemIdentifier: String? = nil,
        user: User? = nil,
        car: Car? = nil,
        createdAt: Date = .now
    ) {
        self.date = date
        self.speedometerKm = speedometerKm
        self.distanceKm = distanceKm
        self.fuelLiters = fuelLiters
        self.fuelSpend = fuelSpend
        self.garageName = garageName
        self.garageSubtitle = garageSubtitle
        self.garageLatitude = garageLatitude
        self.garageLongitude = garageLongitude
        self.garageMapItemIdentifier = garageMapItemIdentifier
        self.user = user
        self.car = car
        self.createdAt = createdAt
    }

    var garageCoordinate: CLLocationCoordinate2D? {
        guard let latitude = garageLatitude, let longitude = garageLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

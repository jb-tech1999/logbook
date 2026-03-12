import Foundation
import SwiftData
import CoreLocation

@Model
final class Trip {
    var startDate: Date
    var endDate: Date?
    var totalDistance: Double // km
    var averageSpeed: Double // km/h
    var maxSpeed: Double // km/h
    var isActive: Bool
    
    // Relationships
    var car: Car?
    @Relationship(deleteRule: .cascade, inverse: \TripPoint.trip)
    var points: [TripPoint]? = []
    
    init(
        startDate: Date = .now,
        endDate: Date? = nil,
        totalDistance: Double = 0,
        averageSpeed: Double = 0,
        maxSpeed: Double = 0,
        isActive: Bool = true,
        car: Car? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.totalDistance = totalDistance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.isActive = isActive
        self.car = car
    }
    
    // Computed properties
    var duration: TimeInterval? {
        guard let endDate = endDate else { return nil }
        return endDate.timeIntervalSince(startDate)
    }
    
    var durationFormatted: String {
        guard let duration = duration else { return "In progress..." }
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

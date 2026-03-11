import ActivityKit
import Foundation

// MARK: - Trip Live Activity Attributes

struct TripLiveActivityAttributes: ActivityAttributes {
    
    // MARK: - Static Content (doesn't change during activity lifetime)
    public struct ContentState: Codable, Hashable {
        // Dynamic content that updates during the trip
        var distanceTraveled: Double // in km
        var currentSpeed: Double // in km/h
        var duration: TimeInterval // seconds since start
        var startDate: Date
        var isActive: Bool
    }
    
    // Static attributes (set once when activity starts)
    let carMake: String?
    let carModel: String?
    let carYear: Int?
    let tripStartDate: Date
}

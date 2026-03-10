import Foundation
import SwiftData

@Model
final class Car {
    var model: String
    var year: Int
    var make: String
    @Attribute(.unique) var registration: String
    var nickname: String?
    var createdAt: Date
    var owner: User?

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.car)
    var logs: [LogEntry] = []

    init(
        model: String,
        year: Int,
        make: String,
        registration: String,
        nickname: String? = nil,
        owner: User? = nil,
        createdAt: Date = .now
    ) {
        self.model = model
        self.year = year
        self.make = make
        self.registration = registration
        self.nickname = nickname
        self.owner = owner
        self.createdAt = createdAt
    }
}

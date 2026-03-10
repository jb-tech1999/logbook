import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var email: String
    var displayName: String
    var passwordDigest: String
    var usesBiometrics: Bool
    var sessionToken: String?
    var lastSignIn: Date?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Car.owner)
    var cars: [Car] = []

    @Relationship(deleteRule: .cascade, inverse: \LogEntry.user)
    var logs: [LogEntry] = []

    init(
        email: String,
        displayName: String,
        passwordDigest: String,
        usesBiometrics: Bool = false,
        sessionToken: String? = nil,
        createdAt: Date = .now
    ) {
        self.email = email
        self.displayName = displayName
        self.passwordDigest = passwordDigest
        self.usesBiometrics = usesBiometrics
        self.sessionToken = sessionToken
        self.createdAt = createdAt
    }
}

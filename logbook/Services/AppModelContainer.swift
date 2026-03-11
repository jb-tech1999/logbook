import SwiftData

/// App-only SwiftData container bootstrapper.
enum AppModelContainer {
    static func makeSharedContainer() -> ModelContainer {
        do {
            let schema = Schema([User.self, Car.self, LogEntry.self, Trip.self, TripPoint.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier(SharedModelContainer.appGroupIdentifier)
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to bootstrap shared SwiftData container: \(error)")
        }
    }
}

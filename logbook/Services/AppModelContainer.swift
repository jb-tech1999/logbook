import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.jb-tech.logbook", category: "AppModelContainer")

/// App-only SwiftData container bootstrapper.
enum AppModelContainer {

    /// Creates the shared ModelContainer stored in the App Group container.
    /// Returns nil and logs a structured error instead of calling fatalError,
    /// allowing the caller to present a recovery UI rather than crashing.
    static func makeSharedContainer() -> ModelContainer? {
        let schema = Schema([User.self, Car.self, LogEntry.self, Trip.self, TripPoint.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .identifier(SharedModelContainer.appGroupIdentifier)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            logger.info("SwiftData container bootstrapped successfully")
            return container
        } catch {
            logger.critical("Failed to bootstrap shared SwiftData container: \(error)")
            return nil
        }
    }
}

import Foundation
import WidgetKit
import OSLog

private let widgetSnapshotLogger = Logger(subsystem: "com.jb-tech.logbook", category: "DashboardMetricsProvider")

// MARK: - Snapshot storage shared between app and widget

struct DashboardMetricsSnapshot: Codable {
    let userDisplayName: String
    let totalDistance: Double
    let totalFuel: Double
    let totalSpend: Double
    let totalEntries: Int
    let avgFuelEfficiency: Double
    let costPerKm: Double
    let avgCostPerLitre: Double
    let lastFillUpDate: Date?
    let lastFillUpLitres: Double?
    let lastFillUpSpend: Double?
    let lastGarageName: String?
    let recentCarLabel: String?

    // Hardcoded here so the widget extension only needs THIS file to compile —
    // no dependency on SharedModelContainer or any other app-only type.
    static let appGroupID  = "group.com.personal.logbook"
    static let defaultsKey = "logbook_widget_snapshot"

    // MARK: - Placeholder
    static let placeholder = DashboardMetricsSnapshot(
        userDisplayName: "Driver",
        totalDistance: 12_850,
        totalFuel: 940,
        totalSpend: 21_500,
        totalEntries: 48,
        avgFuelEfficiency: 13.7,
        costPerKm: 1.67,
        avgCostPerLitre: 22.9,
        lastFillUpDate: Calendar.current.date(byAdding: .day, value: -2, to: .now),
        lastFillUpLitres: 42.5,
        lastFillUpSpend: 975,
        lastGarageName: "Shell Garage",
        recentCarLabel: "2022 Toyota Corolla"
    )

    // MARK: - Write  (main app → shared UserDefaults)
    func persist() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else {
            widgetSnapshotLogger.error("App Group '\(Self.appGroupID)' not accessible — check Signing & Capabilities")
            return
        }

        do {
            let data = try JSONEncoder().encode(self)
            defaults.set(data, forKey: Self.defaultsKey)
            defaults.synchronize()                          // force flush before WidgetKit reads
            WidgetCenter.shared.reloadAllTimelines()
            let e = avgFuelEfficiency.formatted(.number.precision(.fractionLength(1)))
            widgetSnapshotLogger.info("Persisted widget snapshot with \(self.totalEntries) entries and efficiency \(e) km/L")
        } catch {
            widgetSnapshotLogger.error("Failed to encode widget snapshot: \(error)")
        }
    }

    // MARK: - Read  (widget extension ← shared UserDefaults)
    static func load() -> DashboardMetricsSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            widgetSnapshotLogger.error("App Group '\(self.appGroupID)' not accessible when loading widget snapshot")
            return .placeholder
        }

        guard let data = defaults.data(forKey: defaultsKey) else {
            widgetSnapshotLogger.warning("No widget snapshot found in shared defaults — using placeholder")
            return .placeholder
        }

        do {
            let snapshot = try JSONDecoder().decode(DashboardMetricsSnapshot.self, from: data)
            widgetSnapshotLogger.info("Loaded widget snapshot with \(snapshot.totalEntries) entries")
            return snapshot
        } catch {
            widgetSnapshotLogger.error("Failed to decode widget snapshot: \(error)")
            return .placeholder
        }
    }
}

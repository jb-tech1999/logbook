import Foundation
import SwiftData
import WidgetKit

/// App-only builder that reads SwiftData models and publishes a widget snapshot.
enum AppDashboardMetricsService {

    /// Builds a fresh snapshot from an open ModelContext and persists it
    /// for the widget extension to read from the shared App Group container.
    @discardableResult
    static func buildAndPersist(using context: ModelContext) -> DashboardMetricsSnapshot {
        let snapshot = build(using: context)
        snapshot.persist()
        return snapshot
    }

    private static func build(using context: ModelContext) -> DashboardMetricsSnapshot {
        let logsDescriptor = FetchDescriptor<LogEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let usersDescriptor = FetchDescriptor<User>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let logs = (try? context.fetch(logsDescriptor)) ?? []
        let firstUser = (try? context.fetch(usersDescriptor))?.first
        let userName = firstUser.map { $0.displayName.isEmpty ? "Driver" : $0.displayName } ?? "Driver"

        let totals = logs.reduce(into: (distance: 0.0, fuel: 0.0, spend: 0.0)) { acc, entry in
            acc.distance += entry.distanceKm
            acc.fuel += entry.fuelLiters
            acc.spend += entry.fuelSpend
        }

        let avgEfficiency = totals.fuel > 0 ? totals.distance / totals.fuel : 0
        let costPerKm = totals.distance > 0 ? totals.spend / totals.distance : 0
        let avgCostPerLitre = totals.fuel > 0 ? totals.spend / totals.fuel : 0
        let lastFuelLog = logs.first { $0.fuelLiters > 0 }
        let recentCarLabel: String? = logs.first?.car.map { "\($0.year) \($0.make) \($0.model)" }

        return DashboardMetricsSnapshot(
            userDisplayName: userName,
            totalDistance: totals.distance,
            totalFuel: totals.fuel,
            totalSpend: totals.spend,
            totalEntries: logs.count,
            avgFuelEfficiency: avgEfficiency,
            costPerKm: costPerKm,
            avgCostPerLitre: avgCostPerLitre,
            lastFillUpDate: lastFuelLog?.date,
            lastFillUpLitres: lastFuelLog?.fuelLiters,
            lastFillUpSpend: lastFuelLog?.fuelSpend,
            lastGarageName: lastFuelLog?.garageName,
            recentCarLabel: recentCarLabel
        )
    }
}

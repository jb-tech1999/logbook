import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    let onSignOut: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\User.createdAt, order: .reverse)])
    private var users: [User]

    @Query(sort: [SortDescriptor(\Car.createdAt, order: .reverse)])
    private var cars: [Car]

    @Query(sort: [SortDescriptor(\LogEntry.date, order: .reverse)])
    private var logs: [LogEntry]

    @State private var selectedTrendRange: FuelTrendRange = .month

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                metricsSection
                fuelEconomySection
                carsSection
                logsSection
                footer
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out", role: .destructive, action: onSignOut)
            }
        }
        .task(id: widgetRefreshSignature) {
            AppDashboardMetricsService.buildAndPersist(using: modelContext)
        }
    }

    private var activeUser: User? { users.first }
    private var totalDistance: Double { logs.reduce(0) { $0 + $1.distanceKm } }
    private var totalFuel: Double { logs.reduce(0) { $0 + $1.fuelLiters } }
    private var totalSpend: Double { logs.reduce(0) { $0 + $1.fuelSpend } }
    private var avgCostPerLiter: Double { totalFuel > 0 ? totalSpend / totalFuel : 0 }
    private var avgFuelEfficiency: Double { totalDistance > 0 ? (totalDistance / totalFuel) : 0 }
    private var widgetRefreshSignature: String {
        let latestLogStamp = logs.first?.date.timeIntervalSinceReferenceDate ?? 0
        let userStamp = activeUser?.createdAt.timeIntervalSinceReferenceDate ?? 0
        let carCount = cars.count
        return "\(logs.count)-\(latestLogStamp)-\(userStamp)-\(carCount)"
    }
    private var fuelEconomySamples: [FuelEconomySample] { fuelEconomyData.samples }
    private var fuelEconomyUsesFallback: Bool { fuelEconomyData.fallback }
    private var fuelEconomyData: (samples: [FuelEconomySample], fallback: Bool) {
        let calendar = Calendar.current
        let startDate = selectedTrendRange.startDate(from: Date())
        let fuelLogs = logs.filter { $0.fuelLiters > 0 }

        guard !fuelLogs.isEmpty else { return ([], false) }

        var filteredLogs = fuelLogs.filter { $0.date >= startDate }
        var usedFallback = false

        if filteredLogs.isEmpty {
            filteredLogs = Array(fuelLogs.prefix(12))
            usedFallback = true
        }

        let grouped: [Date: [LogEntry]] = Dictionary(grouping: filteredLogs) { (log: LogEntry) -> Date in
            selectedTrendRange.bucketStart(for: log.date, calendar: calendar)
        }

        let sortedKeys: [Date] = grouped.keys.sorted(by: { (lhs: Date, rhs: Date) -> Bool in
            lhs < rhs
        })

        let samples: [FuelEconomySample] = sortedKeys.compactMap { (key: Date) -> FuelEconomySample? in
            guard let entries = grouped[key] else { return nil }
            let totals = entries.reduce(into: (distance: 0.0, fuel: 0.0)) { partial, entry in
                partial.distance += entry.distanceKm
                partial.fuel += entry.fuelLiters
            }
            guard totals.fuel > 0 else { return nil }
            return FuelEconomySample(date: key, efficiency: totals.distance / totals.fuel)
        }

        return (samples, usedFallback)
    }

    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("Overview", subtitle: "Aggregated driving stats")
            LazyVGrid(columns: grid, spacing: 12) {
                DashboardMetricCard(
                    title: "Distance",
                    value: totalDistance.formatted(.number.precision(.fractionLength(1))) + " km",
                    detail: "Lifetime tracked",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: .blue
                )
                DashboardMetricCard(
                    title: "Fuel",
                    value: totalFuel.formatted(.number.precision(.fractionLength(1))) + " L",
                    detail: "Purchased",
                    systemImage: "fuelpump",
                    tint: .orange
                )
                DashboardMetricCard(
                    title: "Spend",
                    value: totalSpend.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                    detail: "Fuel total",
                    systemImage: "creditcard",
                    tint: .green
                )
                DashboardMetricCard(
                    title: "Avg Fuel Efficiency",
                    value: avgFuelEfficiency.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) + "KM/L",
                    detail: "Efficiency",
                    systemImage: "chart.bar.doc.horizontal",
                    tint: .purple
                )
            }
        }
        .dashboardCardStyle()
    }

    @ViewBuilder
    private var fuelEconomySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Fuel Economy", subtitle: "km per liter over time")

            Picker("Range", selection: $selectedTrendRange) {
                ForEach(FuelTrendRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if fuelEconomySamples.isEmpty {
                emptyState(text: "Not enough log data for this range yet.")
                    .frame(minHeight: 160)
            } else {
                if fuelEconomyUsesFallback {
                    Text("Showing latest logs available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Chart(fuelEconomySamples) { sample in
                    LineMark(
                        x: .value("Date", sample.date),
                        y: .value("km/L", sample.efficiency)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.purple)

                    PointMark(
                        x: .value("Date", sample.date),
                        y: .value("km/L", sample.efficiency)
                    )
                    .foregroundStyle(.purple)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: selectedTrendRange.axisTickCount))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 220)
            }
        }
        .dashboardCardStyle()
    }

    @ViewBuilder
    private var carsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("Garage", subtitle: "Registered vehicles")
            if cars.isEmpty {
                emptyState(text: "Add your first car to begin logging trips.")
            } else {
                ForEach(cars) { car in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(car.year) \(car.make) \(car.model)")
                            .font(.headline)
                        if let nickname = car.nickname, !nickname.isEmpty {
                            Text(nickname)
                                .foregroundColor(.secondary)
                        }
                        Text("Reg: \(car.registration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .overlay(Divider(), alignment: .bottom)
                }
            }
        }
        .dashboardCardStyle()
    }

    @ViewBuilder
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("Recent Logs", subtitle: "Latest trips & fill-ups")
            if logs.isEmpty {
                emptyState(text: "No driving logs yet.")
            } else {
                ForEach(logs.prefix(5)) { log in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.date, style: .date)
                                .font(.headline)
                            Text("\(log.distanceKm.formatted(.number.precision(.fractionLength(1)))) km • \(log.speedometerKm.formatted(.number.precision(.fractionLength(0)))) km/h")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let garage = log.garageName {
                                Label(garage, systemImage: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(log.fuelLiters.formatted(.number.precision(.fractionLength(1))) + " L")
                                .bold()
                            Text(log.fuelSpend.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Divider()
                }
            }
        }
        .dashboardCardStyle()
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text(activeUser?.displayName ?? "Driver")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("© 2025 Jandre Badenhorst")
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
    }

    private func header(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.caption).foregroundColor(.secondary)
        }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.bold())
            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tint.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

private enum FuelTrendRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: FuelTrendRange { self }

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    var axisTickCount: Int {
        switch self {
        case .week: return 7
        case .month: return 6
        case .year: return 6
        }
    }

    func startDate(from reference: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: reference) ?? reference
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: reference) ?? reference
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: reference) ?? reference
        }
    }

    func bucketStart(for date: Date, calendar: Calendar) -> Date {
        switch self {
        case .week:
            return calendar.startOfDay(for: date)
        case .month:
            return calendar.startOfDay(for: date)
        case .year:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }
}

private struct FuelEconomySample: Identifiable {
    let id = UUID()
    let date: Date
    let efficiency: Double
}

private extension View {
    func dashboardCardStyle() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
    }
}

import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct DashboardWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DashboardMetricsSnapshot
}

// MARK: - Timeline Provider

struct DashboardWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> DashboardWidgetEntry {
        DashboardWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardWidgetEntry) -> Void) {
        let entry = context.isPreview
            ? DashboardWidgetEntry(date: .now, snapshot: .placeholder)
            : makeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardWidgetEntry>) -> Void) {
        let entry   = makeEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    // ✅ Reads from App Group UserDefaults — works across process boundaries
    private func makeEntry() -> DashboardWidgetEntry {
        DashboardWidgetEntry(date: .now, snapshot: DashboardMetricsSnapshot.load())
    }
}

// MARK: - Widget Definition

struct DashboardWidget: Widget {
    static let kind = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DashboardWidgetProvider()) { entry in
            DashboardWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Logbook KPIs")
        .description("Your driving stats at a glance — distance, fuel, spend & more.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Root View (family router)

struct DashboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: DashboardWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            case .accessoryCircular:
                AccessoryCircularView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
            default:
                MediumWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "logbook://dashboard"))
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let entry: DashboardWidgetEntry

    private var s: DashboardMetricsSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "fuelpump.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Logbook")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(s.avgFuelEfficiency.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.primary)
                Text("km / L")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 6)
            Divider()
            Spacer(minLength: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(s.totalDistance.formatted(.number.precision(.fractionLength(0)))) km")
                    .font(.subheadline.weight(.semibold))
                    .minimumScaleFactor(0.7)
                Text("Total distance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            // ✅ Fixed: use string interpolation — Text + Text is deprecated in iOS 26
            if let lastDate = s.lastFillUpDate {
                Label {
                    Text("\(lastDate, style: .relative) ago")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let entry: DashboardWidgetEntry

    private var s: DashboardMetricsSnapshot { entry.snapshot }
    private var currencyCode: String { Locale.current.currency?.identifier ?? "ZAR" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Logbook KPIs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(s.userDisplayName)
                        .font(.subheadline.weight(.bold))
                }
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                KPICard(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: .blue,
                    label: "Distance",
                    value: "\(s.totalDistance.formatted(.number.precision(.fractionLength(0)))) km"
                )
                KPICard(
                    icon: "fuelpump.fill",
                    tint: .orange,
                    label: "Fuel",
                    value: "\(s.totalFuel.formatted(.number.precision(.fractionLength(1)))) L"
                )
                KPICard(
                    icon: "creditcard.fill",
                    tint: .green,
                    label: "Total Spend",
                    value: s.totalSpend.formatted(.currency(code: currencyCode))
                )
                KPICard(
                    icon: "chart.bar.fill",
                    tint: .purple,
                    label: "km / L",
                    value: s.avgFuelEfficiency.formatted(.number.precision(.fractionLength(1)))
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Large Widget

private struct LargeWidgetView: View {
    let entry: DashboardWidgetEntry

    private var s: DashboardMetricsSnapshot { entry.snapshot }
    private var currencyCode: String { Locale.current.currency?.identifier ?? "ZAR" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Header ──────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Logbook", systemImage: "fuelpump.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(s.userDisplayName)
                        .font(.title3.weight(.bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(entry.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.date, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            // ── 2×2 KPI grid ────────────────────────────────────────
            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                KPICard(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    tint: .blue,
                    label: "Total Distance",
                    value: "\(s.totalDistance.formatted(.number.precision(.fractionLength(0)))) km"
                )
                KPICard(
                    icon: "fuelpump.fill",
                    tint: .orange,
                    label: "Total Fuel",
                    value: "\(s.totalFuel.formatted(.number.precision(.fractionLength(1)))) L"
                )
                KPICard(
                    icon: "creditcard.fill",
                    tint: .green,
                    label: "Total Spend",
                    value: s.totalSpend.formatted(.currency(code: currencyCode))
                )
                KPICard(
                    icon: "chart.bar.fill",
                    tint: .purple,
                    label: "Avg km / L",
                    value: s.avgFuelEfficiency.formatted(.number.precision(.fractionLength(1)))
                )
            }

            // ── Derived metrics row ──────────────────────────────────
            HStack(spacing: 10) {
                SmallStatPill(
                    icon: "dollarsign.arrow.circlepath",
                    tint: .teal,
                    label: "Cost / km",
                    value: s.costPerKm.formatted(.currency(code: currencyCode))
                )
                SmallStatPill(
                    icon: "drop.fill",
                    tint: .cyan,
                    label: "Cost / L",
                    value: s.avgCostPerLitre.formatted(.currency(code: currencyCode))
                )
                SmallStatPill(
                    icon: "list.bullet.clipboard",
                    tint: .indigo,
                    label: "Entries",
                    value: "\(s.totalEntries)"
                )
            }

            Divider()

            // ── Last fill-up ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("Last Fill-Up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let date = s.lastFillUpDate {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(date, style: .date)
                                .font(.subheadline.weight(.semibold))
                            if let garage = s.lastGarageName {
                                Label(garage, systemImage: "mappin.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let litres = s.lastFillUpLitres {
                                // ✅ Fixed: string interpolation replaces deprecated Text + Text
                                Text("\(litres.formatted(.number.precision(.fractionLength(1)))) L")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                            if let spend = s.lastFillUpSpend {
                                Text(spend.formatted(.currency(code: currencyCode)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("No fill-ups logged yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // ── Car label ────────────────────────────────────────────
            if let car = s.recentCarLabel {
                Spacer(minLength: 0)
                Label(car, systemImage: "car.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Accessory Circular  (Lock Screen / StandBy)

private struct AccessoryCircularView: View {
    let entry: DashboardWidgetEntry

    var body: some View {
        let efficiency = entry.snapshot.avgFuelEfficiency
        Gauge(value: min(efficiency, 20), in: 0...20) {
            Image(systemName: "fuelpump.fill")
        } currentValueLabel: {
            Text(efficiency.formatted(.number.precision(.fractionLength(0))))
                .font(.system(.caption2, design: .rounded).weight(.bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.orange)
    }
}

// MARK: - Accessory Rectangular  (Lock Screen)

private struct AccessoryRectangularView: View {
    let entry: DashboardWidgetEntry

    private var s: DashboardMetricsSnapshot { entry.snapshot }
    private var currencyCode: String { Locale.current.currency?.identifier ?? "ZAR" }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Logbook", systemImage: "fuelpump.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text("\(s.totalDistance.formatted(.number.precision(.fractionLength(0)))) km")
                    .font(.subheadline.weight(.bold))
                Text("•")
                    .foregroundStyle(.secondary)
                Text("\(s.avgFuelEfficiency.formatted(.number.precision(.fractionLength(1)))) km/L")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
            }
            .minimumScaleFactor(0.7)
            .lineLimit(1)

            Text("\(s.totalSpend.formatted(.currency(code: currencyCode))) spent")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Reusable sub-views

private struct KPICard: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SmallStatPill: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    DashboardWidget()
} timeline: {
    DashboardWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    DashboardWidget()
} timeline: {
    DashboardWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview("Large", as: .systemLarge) {
    DashboardWidget()
} timeline: {
    DashboardWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview("Lock Screen Circular", as: .accessoryCircular) {
    DashboardWidget()
} timeline: {
    DashboardWidgetEntry(date: .now, snapshot: .placeholder)
}

#Preview("Lock Screen Rectangular", as: .accessoryRectangular) {
    DashboardWidget()
} timeline: {
    DashboardWidgetEntry(date: .now, snapshot: .placeholder)
}

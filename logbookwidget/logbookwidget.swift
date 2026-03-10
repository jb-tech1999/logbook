//
//  logbookwidget.swift
//  logbookwidget
//
//  Created by Jandre Badenhorst on 2026/03/09.
//

import WidgetKit
import SwiftUI

// MARK: - Snapshot

struct WidgetSnapshot: Codable {
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

    static let appGroupID  = "group.com.personal.logbook"
    static let defaultsKey = "logbook_widget_snapshot"

    static var empty: WidgetSnapshot {
        WidgetSnapshot(
            userDisplayName: "Driver",
            totalDistance: 0, totalFuel: 0, totalSpend: 0,
            totalEntries: 0, avgFuelEfficiency: 0,
            costPerKm: 0, avgCostPerLitre: 0,
            lastFillUpDate: nil, lastFillUpLitres: nil,
            lastFillUpSpend: nil, lastGarageName: nil,
            recentCarLabel: nil
        )
    }

    static func load() -> WidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data     = defaults.data(forKey: defaultsKey),
            let snap     = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snap
    }

    var currency: String { Locale.current.currency?.identifier ?? "ZAR" }

    func fmt(_ value: Double, decimals: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)))
    }
    func fmtCurrency(_ value: Double) -> String {
        value.formatted(.currency(code: currency))
    }
}

// MARK: - Timeline Entry & Provider

struct LogbookEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct LogbookProvider: TimelineProvider {
    func placeholder(in context: Context) -> LogbookEntry {
        LogbookEntry(date: .now, snapshot: .empty)
    }
    func getSnapshot(in context: Context, completion: @escaping (LogbookEntry) -> Void) {
        completion(LogbookEntry(date: .now, snapshot: .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LogbookEntry>) -> Void) {
        let entry   = LogbookEntry(date: .now, snapshot: .load())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Root view

struct LogbookWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LogbookEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(s: entry.snapshot)
        case .systemLarge:  LargeView(s: entry.snapshot, date: entry.date)
        default:            MediumView(s: entry.snapshot)
        }
    }
}

// MARK: - Small

/// Apple HIG: small widget should show a single hero metric with supporting context.
/// Use ViewThatFits so content degrades gracefully at larger Dynamic Type sizes.
private struct SmallView: View {
    let s: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // App label
            Label("Logbook", systemImage: "fuelpump.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Hero metric — ViewThatFits drops the subtitle when space is tight
            ViewThatFits(in: .vertical) {
                // Full version
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.fmt(s.avgFuelEfficiency))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("km / L")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
                // Compact fallback
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.fmt(s.avgFuelEfficiency))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("km/L")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)

            Divider()

            // Supporting stat
            VStack(alignment: .leading, spacing: 1) {
                Text("\(s.fmt(s.totalDistance, decimals: 0)) km")
                    .font(.footnote.weight(.semibold))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text("Total distance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Last fill-up — only shown when it fits
            if let d = s.lastFillUpDate {
                Label("\(d, style: .relative) ago", systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        // ✅ No manual padding — containerBackground handles safe insets
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium

private struct MediumView: View {
    let s: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .firstTextBaseline) {
                Label("Logbook", systemImage: "fuelpump.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(s.userDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.bottom, 8)

            // Two tile rows — each row is a plain HStack so tiles share
            // the remaining height equally via .frame(maxHeight: .infinity)
            HStack(spacing: 8) {
                KPITile(icon: "point.topleft.down.curvedto.point.bottomright.up",
                        tint: .blue,   label: "Distance",
                        value: "\(s.fmt(s.totalDistance, decimals: 0)) km")
                KPITile(icon: "fuelpump.fill",
                        tint: .orange, label: "Fuel",
                        value: "\(s.fmt(s.totalFuel)) L")
            }
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                KPITile(icon: "creditcard.fill",
                        tint: .green,  label: "Spend",
                        value: s.fmtCurrency(s.totalSpend))
                KPITile(icon: "chart.bar.fill",
                        tint: .purple, label: "km / L",
                        value: s.fmt(s.avgFuelEfficiency))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Large

private struct LargeView: View {
    let s: WidgetSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                Label("Logbook", systemImage: "fuelpump.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(s.userDisplayName)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }
            .padding(.bottom, 8)

            // ── 2×2 KPI tiles ────────────────────────────────────────
            // Use two plain HStack rows — each tile has a FIXED height
            // so the widget never compresses or clips them.
            HStack(spacing: 8) {
                KPITile(icon: "point.topleft.down.curvedto.point.bottomright.up",
                        tint: .blue,   label: "Distance",
                        value: "\(s.fmt(s.totalDistance, decimals: 0)) km",
                        fixedHeight: 56)
                KPITile(icon: "fuelpump.fill",
                        tint: .orange, label: "Fuel",
                        value: "\(s.fmt(s.totalFuel)) L",
                        fixedHeight: 56)
            }
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                KPITile(icon: "creditcard.fill",
                        tint: .green,  label: "Spend",
                        value: s.fmtCurrency(s.totalSpend),
                        fixedHeight: 56)
                KPITile(icon: "chart.bar.fill",
                        tint: .purple, label: "Avg km/L",
                        value: s.fmt(s.avgFuelEfficiency),
                        fixedHeight: 56)
            }
            .padding(.bottom, 8)

            // ── Derived stats row ─────────────────────────────────────
            HStack(spacing: 6) {
                StatPill(icon: "dollarsign.arrow.circlepath", tint: .teal,
                         label: "Cost/km", value: s.fmtCurrency(s.costPerKm))
                StatPill(icon: "drop.fill", tint: .cyan,
                         label: "Cost/L",  value: s.fmtCurrency(s.avgCostPerLitre))
                StatPill(icon: "list.bullet.clipboard", tint: .indigo,
                         label: "Logs",   value: "\(s.totalEntries)")
            }
            .padding(.bottom, 8)

            Divider()
                .padding(.bottom, 8)

            // ── Last fill-up ──────────────────────────────────────────
            Text("Last Fill-Up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            if let d = s.lastFillUpDate {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d, style: .date)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                        if let g = s.lastGarageName {
                            Label(g, systemImage: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        if let l = s.lastFillUpLitres {
                            Text("\(s.fmt(l)) L")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                        }
                        if let sp = s.lastFillUpSpend {
                            Text(s.fmtCurrency(sp))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                Text("No fill-ups logged yet")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // ── Vehicle label (only shown when it fits) ───────────────
            if let car = s.recentCarLabel {
                Spacer(minLength: 6)
                Label(car, systemImage: "car.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Shared sub-views

/// KPITile with an optional fixed height.
/// When fixedHeight is provided the tile never compresses its content —
/// the rounded-rect background fills the full fixed height and the
/// text content is aligned to the leading-top corner inside it.
private struct KPITile: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String
    var fixedHeight: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.footnote.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity,
               minHeight: fixedHeight,
               maxHeight: fixedHeight,
               alignment: .topLeading)
        .background(tint.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct StatPill: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Widget definition

struct logbookwidget: Widget {
    let kind: String = "logbookwidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LogbookProvider()) { entry in
            LogbookWidgetEntryView(entry: entry)
                // ✅ containerBackground provides correct safe-area insets automatically
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Logbook KPIs")
        .description("Distance, fuel, spend and efficiency at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    logbookwidget()
} timeline: {
    LogbookEntry(date: .now, snapshot: .empty)
}

#Preview("Medium", as: .systemMedium) {
    logbookwidget()
} timeline: {
    LogbookEntry(date: .now, snapshot: .empty)
}

#Preview("Large", as: .systemLarge) {
    logbookwidget()
} timeline: {
    LogbookEntry(date: .now, snapshot: .empty)
}

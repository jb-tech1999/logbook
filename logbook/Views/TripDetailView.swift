import SwiftUI
import SwiftData
import MapKit
import Charts

struct TripDetailView: View {
    let trip: Trip
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showingShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map with route
                mapSection
                
                // Stats cards
                statsSection
                
                // Speed chart
                if let points = trip.points, !points.isEmpty {
                    speedChartSection(points: points)
                }
                
                // Trip details
                detailsSection
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share trip")
                .accessibilityHint("Share trip details via message or other apps")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [generateTripSummary()])
        }
        .animation(reduceMotion ? nil : .default, value: showingShareSheet)
        .onAppear {
            setupMapRegion()
        }
    }
    
    private var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Map {
                // Color-coded route segments (red = slow/stopped, green = max speed)
                if let points = trip.points, points.count > 1 {
                    let maxSpeed = trip.maxSpeed > 0 ? trip.maxSpeed : 100 // Fallback to 100 if no max
                    
                    // Draw segments between consecutive points with speed-based colors
                    ForEach(0..<(points.count - 1), id: \.self) { index in
                        let startPoint = points[index]
                        let endPoint = points[index + 1]
                        let segmentSpeed = startPoint.speed
                        let segmentColor = colorForSpeed(segmentSpeed, maxSpeed: maxSpeed)
                        
                        MapPolyline(coordinates: [startPoint.coordinate, endPoint.coordinate])
                            .stroke(segmentColor, lineWidth: 5)
                    }
                }
                
                // Start marker
                if let firstPoint = trip.points?.first {
                    Annotation("Start", coordinate: firstPoint.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(.green)
                                .frame(width: 24, height: 24)
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel("Trip start location")
                        .accessibilityHint("Marks where the trip began")
                    }
                }
                
                // End marker
                if let lastPoint = trip.points?.last, !trip.isActive {
                    Annotation("End", coordinate: lastPoint.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(.red)
                                .frame(width: 24, height: 24)
                            Image(systemName: "flag.checkered")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel("Trip end location")
                        .accessibilityHint("Marks where the trip ended")
                    }
                }
            }
            
            // Speed legend
            speedLegend
                .padding(12)
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private var speedLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Speed")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 2) {
                // Color gradient bar
                LinearGradient(
                    colors: [.red, .yellow, .green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 60, height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            
            HStack(spacing: 0) {
                Text("0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(trip.maxSpeed))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                icon: "point.topleft.down.curvedto.point.bottomright.up",
                title: "Distance",
                value: "\(trip.totalDistance.formatted(.number.precision(.fractionLength(1)))) km",
                color: .blue
            )
            
            StatCard(
                icon: "clock",
                title: "Duration",
                value: trip.durationFormatted,
                color: .orange
            )
            
            StatCard(
                icon: "gauge.with.needle",
                title: "Avg Speed",
                value: "\(trip.averageSpeed.formatted(.number.precision(.fractionLength(0)))) km/h",
                color: .green
            )
            
            StatCard(
                icon: "speedometer",
                title: "Max Speed",
                value: "\(trip.maxSpeed.formatted(.number.precision(.fractionLength(0)))) km/h",
                color: .red
            )
        }
        .padding(.horizontal)
    }
    
    private func speedChartSection(points: [TripPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speed Over Time")
                .font(.headline)
                .padding(.horizontal)
            
            Chart(points) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Speed", point.speed)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 200)
            .chartYAxisLabel("Speed (km/h)")
            .padding(.horizontal)
            .accessibilityLabel("Speed over time chart")
            .accessibilityValue("Trip speed ranged from 0 to \(Int(trip.maxSpeed)) kilometers per hour, with an average of \(Int(trip.averageSpeed)) kilometers per hour")
        }
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trip Information")
                .font(.headline)
            
            DetailRow(label: "Start Time", value: trip.startDate.formatted(date: .abbreviated, time: .shortened))
            
            if let endDate = trip.endDate {
                DetailRow(label: "End Time", value: endDate.formatted(date: .abbreviated, time: .shortened))
            }
            
            if let car = trip.car {
                DetailRow(label: "Vehicle", value: "\(car.year) \(car.make) \(car.model)")
            }
            
            if let points = trip.points {
                DetailRow(label: "Data Points", value: "\(points.count)")
            }
            
            DetailRow(
                label: "Status",
                value: trip.isActive ? "Active" : "Completed"
            )
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private func setupMapRegion() {
        guard let points = trip.points, !points.isEmpty else { return }
        
        let coordinates = points.map { $0.coordinate }
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.3)
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
    
    // MARK: - Speed Color Gradient
    
    /// Returns a color from red (slow/stopped) through yellow to green (max speed)
    private func colorForSpeed(_ speed: Double, maxSpeed: Double) -> Color {
        // Normalize speed to 0.0 - 1.0 range
        let normalizedSpeed = maxSpeed > 0 ? min(speed / maxSpeed, 1.0) : 0.0
        
        if normalizedSpeed < 0.5 {
            // Red to Yellow (0.0 to 0.5)
            let factor = normalizedSpeed * 2.0 // Scale to 0-1
            return Color(
                red: 1.0,
                green: factor,
                blue: 0.0
            )
        } else {
            // Yellow to Green (0.5 to 1.0)
            let factor = (normalizedSpeed - 0.5) * 2.0 // Scale to 0-1
            return Color(
                red: 1.0 - factor,
                green: 1.0,
                blue: 0.0
            )
        }
    }
    
    private func generateTripSummary() -> String {
        var summary = "🚗 Trip Summary\n\n"
        summary += "📅 Date: \(trip.startDate.formatted(date: .abbreviated, time: .shortened))\n"
        summary += "📍 Distance: \(trip.totalDistance.formatted(.number.precision(.fractionLength(1)))) km\n"
        summary += "⏱️ Duration: \(trip.durationFormatted)\n"
        summary += "📊 Avg Speed: \(trip.averageSpeed.formatted(.number.precision(.fractionLength(0)))) km/h\n"
        summary += "🚀 Max Speed: \(trip.maxSpeed.formatted(.number.precision(.fractionLength(0)))) km/h\n"
        
        if let car = trip.car {
            summary += "🚙 Vehicle: \(car.year) \(car.make) \(car.model)\n"
        }
        
        summary += "\nGenerated by Logbook"
        
        return summary
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date(),
            totalDistance: 45.3,
            averageSpeed: 68,
            maxSpeed: 120,
            isActive: false
        ))
    }
    .modelContainer(for: [Trip.self, TripPoint.self], inMemory: true)
}

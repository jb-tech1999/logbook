import SwiftUI
import SwiftData
import MapKit

struct TripsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var tripTrackingService: TripTrackingService
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @Query private var cars: [Car]
    @State private var selectedTrip: Trip?
    @State private var showingCarSelection = false
    @State private var selectedCar: Car?
    
    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty && !tripTrackingService.isTracking {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Active trip banner
                        if tripTrackingService.isTracking {
                            activeTripBanner
                        }
                        
                        // Trip control button
                        tripControlSection
                        
                        // Trips list
                        if !trips.isEmpty {
                            tripsList
                        }
                    }
                }
            }
            .navigationTitle("Trips")
            .navigationDestination(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
            .sheet(isPresented: $showingCarSelection) {
                carSelectionSheet
            }
        }
    }
    
    private var activeTripBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(.red.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .scaleEffect(tripTrackingService.isTracking ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: tripTrackingService.isTracking)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Recording Trip")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    Label("\(tripTrackingService.distanceTraveled, format: .number.precision(.fractionLength(1))) km", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    Label("\(tripTrackingService.currentSpeed, format: .number.precision(.fractionLength(0))) km/h", systemImage: "speedometer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.red.opacity(0.1))
    }
    
    private var tripControlSection: some View {
        VStack(spacing: 12) {
            if tripTrackingService.isTracking {
                Button(action: stopTrip) {
                    Label("Stop Trip", systemImage: "stop.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button(action: { showingCarSelection = true }) {
                    Label("Start New Trip", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var carSelectionSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedCar = nil
                        showingCarSelection = false
                        startTrip()
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                            Text("No specific car")
                                .foregroundStyle(.primary)
                        }
                    }
                }
                
                if !cars.isEmpty {
                    Section("Select Vehicle") {
                        ForEach(cars) { car in
                            Button {
                                selectedCar = car
                                showingCarSelection = false
                                startTrip()
                            } label: {
                                HStack {
                                    Image(systemName: "car.fill")
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(car.year) \(car.make) \(car.model)")
                                            .foregroundStyle(.primary)
                                        Text(car.registration)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("No vehicles added yet. Add a vehicle in the Garage tab first.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Start Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCarSelection = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Trips Yet")
                .font(.title2.bold())
            
            Text("Tap 'Start New Trip' to begin tracking your journey")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Start trip button
            Button(action: { showingCarSelection = true }) {
                Label("Start New Trip", systemImage: "play.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var tripsList: some View {
        List {
            ForEach(trips) { trip in
                TripRowView(trip: trip)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTrip = trip
                    }
            }
            .onDelete(perform: deleteTrips)
        }
    }
    
    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            let trip = trips[index]
            // Delete all associated trip points first
            if let points = trip.points {
                for point in points {
                    modelContext.delete(point)
                }
            }
            modelContext.delete(trip)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete trips: \(error)")
        }
    }
    
    private func startTrip() {
        tripTrackingService.startTracking(car: selectedCar)
    }
    
    private func stopTrip() {
        tripTrackingService.stopTracking()
    }
}

struct TripRowView: View {
    let trip: Trip
    
    var body: some View {
        HStack(spacing: 16) {
            // Map icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: trip.isActive ? "location.fill" : "map.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Date and status
                HStack {
                    Text(trip.startDate, style: .date)
                        .font(.headline)
                    
                    if trip.isActive {
                        Text("Active")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                
                // Stats
                HStack(spacing: 16) {
                    Label {
                        Text("\(trip.totalDistance, format: .number.precision(.fractionLength(1))) km")
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                            .foregroundStyle(.secondary)
                    }
                    
                    Label {
                        Text(trip.durationFormatted)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.secondary)
                .font(.caption)
                
                // Speed stats
                if !trip.isActive {
                    HStack(spacing: 12) {
                        Text("Avg: \(trip.averageSpeed, format: .number.precision(.fractionLength(0))) km/h")
                        Text("•")
                        Text("Max: \(trip.maxSpeed, format: .number.precision(.fractionLength(0))) km/h")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                
                // Car info
                if let car = trip.car {
                    Label("\(car.year) \(car.make) \(car.model)", systemImage: "car.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TripsView()
        .modelContainer(for: [Trip.self, TripPoint.self, Car.self], inMemory: true)
}

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

private enum MapStyle: Equatable {
    case standard
    case hybrid
    case imagery
}

private extension MapStyle {
    var toMKMapStyle: MapKit.MapStyle {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        case .imagery:
            return .imagery
        }
    }
}

struct GarageMapView: View {
    var locationManager: LocationManager
    let onSignOut: () -> Void

    @Query(sort: [SortDescriptor(\User.createdAt, order: .reverse)])
    private var users: [User]
    
    @Query(sort: [SortDescriptor(\LogEntry.date, order: .reverse)])
    private var logEntries: [LogEntry]

    @State private var garageSuggestions: [GarageSuggestion] = []
    @State private var selectedSuggestion: GarageSuggestion?
    @State private var showDirectionsPrompt = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCenteredCamera = false
    @State private var isPanelMinimized = false
    @State private var currentRoute: MKRoute?
    @State private var isNavigating = false
    @State private var isCalculatingRoute = false
    @State private var mapStyle: MapStyle = .standard

    private let garageService = GarageService()

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            controlPanel
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Garages Map")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out", role: .destructive, action: onSignOut)
            }
        }
        .task {
            await loadGarages()
            if !hasCenteredCamera, let coordinate = locationManager.lastKnownLocation {
                centerCamera(on: coordinate)
            }
        }
        .alert("Navigate to Garage", isPresented: $showDirectionsPrompt, presenting: selectedSuggestion) { suggestion in
            Button("Open in Maps") {
                openInMaps(suggestion)
            }
            Button("Show Route") {
                Task {
                    await startNavigation(to: suggestion)
                }
            }
            Button("Cancel", role: .cancel) {
                selectedSuggestion = nil
            }
        } message: { suggestion in
            Text("Get directions to \(suggestion.name)?")
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 0) {
            if isPanelMinimized {
                // Minimized: just a tiny chevron button
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isPanelMinimized = false
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 18)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)
            } else {
                // Expanded: show full panel
                VStack(spacing: 12) {
                    // Compact minimize button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isPanelMinimized = true
                        }
                    } label: {
                        Capsule()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 36, height: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    
                    mainPanelContent
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private var mainPanelContent: some View {
        VStack(spacing: 12) {
            if isNavigating, let route = currentRoute {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.turn.up.right")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedSuggestion?.name ?? "Destination")
                                .font(.headline)
                            HStack(spacing: 12) {
                                Label(formatDistance(route.distance), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                Label(formatDuration(route.expectedTravelTime), systemImage: "clock")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            stopNavigation()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                HStack {
                    Text("Your Garages")
                        .font(.headline)
                    Spacer()
                    if isCalculatingRoute {
                        ProgressView().controlSize(.small)
                    } else {
                        HStack(spacing: 8) {
                            Menu {
                                Button {
                                    mapStyle = .standard
                                } label: {
                                    Label("Standard", systemImage: mapStyle == .standard ? "checkmark" : "")
                                }
                                Button {
                                    mapStyle = .hybrid
                                } label: {
                                    Label("Hybrid", systemImage: mapStyle == .hybrid ? "checkmark" : "")
                                }
                                Button {
                                    mapStyle = .imagery
                                } label: {
                                    Label("Satellite", systemImage: mapStyle == .imagery ? "checkmark" : "")
                                }
                            } label: {
                                Image(systemName: "map")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            if locationManager.lastKnownLocation != nil {
                                Button {
                                    if let coordinate = locationManager.lastKnownLocation {
                                        centerCamera(on: coordinate, span: 0.03)
                                    }
                                } label: {
                                    Image(systemName: "location.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            Button {
                                Task { await loadGarages(force: true) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            if garageSuggestions.isEmpty {
                Text("No previous garages yet.\nLog your first refuel to see it here!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(garageSuggestions) { suggestion in
                            garageListItem(for: suggestion)
                            if suggestion.id != garageSuggestions.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            if locationManager.lastKnownLocation == nil {
                Button {
                    locationManager.checkLocationAuthorization()
                } label: {
                    Label("Enable Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Text("Tap a garage for directions")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            if let coordinate = locationManager.lastKnownLocation {
                Annotation("You", coordinate: coordinate) {
                    userAnnotation
                        .accessibilityLabel("Your location")
                        .accessibilityHint("Shows your current position on the map")
                }
            }

            ForEach(garageSuggestions) { suggestion in
                Annotation(suggestion.name, coordinate: suggestion.coordinate) {
                    mapAnnotation(for: suggestion)
                        .accessibilityLabel("Garage: \(suggestion.name)")
                        .accessibilityHint("Double tap to get directions")
                    }
            }

            if let route = currentRoute {
                MapPolyline(route.polyline)
                    .stroke(.blue, lineWidth: 5)
            }
        }
        .mapStyle(mapStyle.toMKMapStyle)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
            MapPitchToggle()
        }
        .ignoresSafeArea(edges: .horizontal)
        .overlay {
            // Show location prompt only when no location and no garages
            if locationManager.lastKnownLocation == nil && garageSuggestions.isEmpty {
                VStack(spacing: 16) {
                    placeholderState
                    Button {
                        locationManager.checkLocationAuthorization()
                    } label: {
                        Label("Enable Location", systemImage: "location.fill")
                            .font(.headline)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
    }

    private var userAnnotation: some View {
        ZStack {
            // Pulsing outer ring
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 32, height: 32)
            
            // Core dot
            Circle()
                .fill(.blue)
                .frame(width: 16, height: 16)
            
            // White border
            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: 20, height: 20)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    private func mapAnnotation(for suggestion: GarageSuggestion) -> some View {
        Button {
            selectSuggestion(suggestion)
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(.orange)
                        .frame(width: 28, height: 28)
                    Circle()
                        .stroke(.white, lineWidth: 2.5)
                        .frame(width: 32, height: 32)
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                
                // Show distance if selected
                if selectedSuggestion?.id == suggestion.id,
                   let distanceText = userDistanceString(to: suggestion) {
                    Text(distanceText)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 2)
                        .padding(.top, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Garage: \(suggestion.name)")
        .accessibilityValue(suggestion.subtitle.isEmpty ? "No additional details" : suggestion.subtitle)
        .accessibilityHint("Double tap to open navigation options")
    }

    private func garageListItem(for suggestion: GarageSuggestion) -> some View {
        Button {
            selectSuggestion(suggestion)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                    .frame(width: 36, height: 36)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let distance = userDistanceString(to: suggestion) {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text(distance)
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.semibold))
                    
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Garage: \(suggestion.name)")
        .accessibilityValue(suggestion.subtitle.isEmpty ? (userDistanceString(to: suggestion) ?? "") : "\(suggestion.subtitle), \(userDistanceString(to: suggestion) ?? "")")
        .accessibilityHint("Double tap to open directions")
    }

    private func selectedGarageActions(for suggestion: GarageSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Garage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(suggestion.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if let distance = userDistanceString(to: suggestion) {
                        Label(distance, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if isNavigating {
                    Button(role: .destructive) {
                        stopNavigation()
                    } label: {
                        Label("Stop", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button {
                Task { await startNavigation(to: suggestion) }
            } label: {
                Label("Navigate in App", systemImage: "arrow.turn.up.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                openInMaps(suggestion)
            } label: {
                Label("Open in Apple Maps", systemImage: "map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var placeholderState: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.title)
                .foregroundColor(.gray)
            Text("Location Needed").font(.headline)
            Text("Allow location access to discover nearby garages.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var activeUser: User? { users.first }

    private var bestCoordinate: CLLocationCoordinate2D? {
        locationManager.lastKnownLocation ?? garageSuggestions.first?.coordinate
    }

    private func selectSuggestion(_ suggestion: GarageSuggestion) {
        selectedSuggestion = suggestion
        showDirectionsPrompt = true
    }

    private func openInMaps(_ suggestion: GarageSuggestion) {
        // Modern iOS 26 API: Use init(location:address:) instead of deprecated placemark
        let location = CLLocation(latitude: suggestion.coordinate.latitude, longitude: suggestion.coordinate.longitude)
        let address = MKAddress(fullAddress: suggestion.subtitle, shortAddress: nil)
        let mapItem = MKMapItem(location: location, address: address)
        mapItem.name = suggestion.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    @MainActor
    private func loadGarages(force: Bool = false) async {
        // Load garages from user's previous log entries instead of searching nearby
        
        #if DEBUG
        print("🔍 Loading garages from log entries...")
        print("📊 Total log entries: \(logEntries.count)")
        #endif
        
        // Get unique garages from log entries
        var seenIdentifiers = Set<String>()
        var uniqueGarages: [GarageSuggestion] = []
        
        for (index, entry) in logEntries.enumerated() {
            #if DEBUG
            print("📝 Entry \(index + 1): garageName=\(entry.garageName ?? "nil"), lat=\(entry.garageLatitude?.description ?? "nil"), lon=\(entry.garageLongitude?.description ?? "nil")")
            #endif
            
            // Skip entries without garage information
            guard let name = entry.garageName,
                  let coordinate = entry.garageCoordinate else {
                #if DEBUG
                print("  ⏭️ Skipping - missing name or coordinates")
                #endif
                continue
            }
            
            // Create a unique identifier for this garage
            let identifier: String
            if let mapItemId = entry.garageMapItemIdentifier, !mapItemId.isEmpty {
                // Use the MKMapItem unique identifier if available
                identifier = mapItemId
            } else {
                // Fallback: use name + PRECISE coordinates (not rounded)
                // This ensures different locations aren't grouped together
                identifier = "\(name)_\(coordinate.latitude)_\(coordinate.longitude)"
            }
            
            #if DEBUG
            print("  🔑 Identifier: \(identifier)")
            #endif
            
            // Skip if we've already seen this garage
            if seenIdentifiers.contains(identifier) {
                #if DEBUG
                print("  ⏭️ Skipping - duplicate identifier")
                #endif
                continue
            }
            seenIdentifiers.insert(identifier)
            
            // Create GarageSuggestion from log entry
            let suggestion = GarageSuggestion(
                name: name,
                subtitle: entry.garageSubtitle ?? "",
                coordinate: coordinate,
                mapItemIdentifier: entry.garageMapItemIdentifier
            )
            uniqueGarages.append(suggestion)
            
            #if DEBUG
            print("  ✅ Added garage: \(name) at (\(coordinate.latitude), \(coordinate.longitude))")
            #endif
        }
        
        garageSuggestions = uniqueGarages
        
        #if DEBUG
        print("🎯 Final unique garages count: \(garageSuggestions.count)")
        for (index, garage) in garageSuggestions.enumerated() {
            print("  \(index + 1). \(garage.name) - \(garage.subtitle)")
            print("     Coordinates: (\(garage.coordinate.latitude), \(garage.coordinate.longitude))")
        }
        #endif
        
        // Center camera to show all garages or user location
        if !hasCenteredCamera {
            if garageSuggestions.count > 1 {
                // Calculate bounding box for all garages
                var minLat = Double.infinity
                var maxLat = -Double.infinity
                var minLon = Double.infinity
                var maxLon = -Double.infinity
                
                for garage in garageSuggestions {
                    minLat = min(minLat, garage.coordinate.latitude)
                    maxLat = max(maxLat, garage.coordinate.latitude)
                    minLon = min(minLon, garage.coordinate.longitude)
                    maxLon = max(maxLon, garage.coordinate.longitude)
                }
                
                // Add some padding (20%)
                let latPadding = (maxLat - minLat) * 0.2
                let lonPadding = (maxLon - minLon) * 0.2
                
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                )
                
                let span = MKCoordinateSpan(
                    latitudeDelta: max((maxLat - minLat) + latPadding, 0.01),
                    longitudeDelta: max((maxLon - minLon) + lonPadding, 0.01)
                )
                
                cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
                hasCenteredCamera = true
                
                #if DEBUG
                print("📍 Camera positioned to show all garages:")
                print("   Center: (\(center.latitude), \(center.longitude))")
                print("   Span: (\(span.latitudeDelta), \(span.longitudeDelta))")
                #endif
            } else if let firstGarage = garageSuggestions.first {
                centerCamera(on: firstGarage.coordinate, span: 0.1)
            } else if let userLocation = locationManager.lastKnownLocation {
                centerCamera(on: userLocation)
            }
        }
    }

    private func centerCamera(on coordinate: CLLocationCoordinate2D, span: CLLocationDegrees = 0.05) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
        )
        hasCenteredCamera = true
    }

    @MainActor
    private func startNavigation(to suggestion: GarageSuggestion) async {
        guard let userLocation = locationManager.lastKnownLocation else { return }

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        let request = MKDirections.Request()
        // Modern iOS 26 API: Use init(location:address:) instead of deprecated placemark
        let sourceLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        request.source = MKMapItem(location: sourceLocation, address: nil)
        
        let destLocation = CLLocation(latitude: suggestion.coordinate.latitude, longitude: suggestion.coordinate.longitude)
        let destAddress = MKAddress(fullAddress: suggestion.subtitle, shortAddress: nil)
        request.destination = MKMapItem(location: destLocation, address: destAddress)
        request.transportType = .automobile

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            
            if let route = response.routes.first {
                currentRoute = route
                isNavigating = true
                selectedSuggestion = suggestion
                
                // Use MapCameraPosition.rect for better route framing
                let rect = route.polyline.boundingMapRect
                let paddedRect = rect.insetBy(dx: -rect.size.width * 0.1, dy: -rect.size.height * 0.1)
                cameraPosition = .rect(paddedRect)
            }
        } catch {
            print("Failed to calculate route: \(error.localizedDescription)")
        }
    }

    private func stopNavigation() {
        currentRoute = nil
        isNavigating = false
        selectedSuggestion = nil
        
        if let coordinate = locationManager.lastKnownLocation {
            centerCamera(on: coordinate, span: 0.05)
        }
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let km = meters / 1000
        if km < 1 {
            return String(format: "%.0f m", meters)
        }
        return String(format: "%.1f km", km)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    private func userDistanceString(to suggestion: GarageSuggestion) -> String? {
        guard let userCoordinate = locationManager.lastKnownLocation else { return nil }
        let meters = userCoordinate.distance(from: suggestion.coordinate)
        return "\(formatDistance(meters)) away"
    }
}

private extension CLLocationCoordinate2D {
    func distance(from other: CLLocationCoordinate2D) -> CLLocationDistance {
        let current = CLLocation(latitude: latitude, longitude: longitude)
        let target = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return current.distance(from: target)
    }
}

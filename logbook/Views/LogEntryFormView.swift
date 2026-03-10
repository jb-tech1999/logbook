import SwiftUI
import SwiftData
import MapKit

struct LogEntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let user: User?
    let cars: [Car]
    @ObservedObject var locationManager: LocationManager
    let existingLog: LogEntry?

    @State private var date: Date
    @State private var selectedCarRegistration: String?
    @State private var odometerReading: String
    @State private var tripDistance: String
    @State private var fuelLiters: String
    @State private var fuelSpend: String
    @State private var selectedGarageID: GarageSuggestion.ID?
    @State private var garageSuggestions: [GarageSuggestion] = []
    @State private var customGarageName: String
    @State private var customGarageDetails: String
    @State private var isFetchingGarages = false
    @State private var garageSearchQuery = ""
    @State private var lastGarageSearchQuery: String?
    @State private var isSearchingGarages = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let garageService = GarageService()

    init(
        user: User?,
        cars: [Car],
        locationManager: LocationManager,
        log: LogEntry? = nil
    ) {
        self.user = user
        self.cars = cars
        self.locationManager = locationManager
        self.existingLog = log

        _date = State(initialValue: log?.date ?? Date())
        _selectedCarRegistration = State(initialValue: log?.car?.registration ?? cars.first?.registration)
        _odometerReading = State(initialValue: LogEntryFormView.formattedString(from: log?.speedometerKm))
        _tripDistance = State(initialValue: LogEntryFormView.formattedString(from: log?.distanceKm))
        _fuelLiters = State(initialValue: LogEntryFormView.formattedString(from: log?.fuelLiters))
        _fuelSpend = State(initialValue: LogEntryFormView.formattedString(from: log?.fuelSpend))
        _customGarageName = State(initialValue: log?.garageName ?? "")
        _customGarageDetails = State(initialValue: log?.garageSubtitle ?? "")
    }

    var body: some View {
        Form {
            if cars.isEmpty && existingLog == nil {
                Section {
                    Text("Add a vehicle before logging trips.")
                        .foregroundColor(.secondary)
                }
            } else {
                Section("Trip") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    Picker("Vehicle", selection: $selectedCarRegistration) {
                        Text("Select a car").tag(String?.none)
                        ForEach(cars, id: \.registration) { car in
                            Text("\(car.year) \(car.make) \(car.model)")
                                .tag(String?.some(car.registration))
                        }
                    }

                    TextField("Speedometer (km)", text: $odometerReading)
                        .keyboardType(.decimalPad)

                    TextField("Distance (km)", text: $tripDistance)
                        .keyboardType(.decimalPad)
                }

                Section("Fuel") {
                    TextField("Fuel purchased (L)", text: $fuelLiters)
                        .keyboardType(.decimalPad)
                    TextField("Fuel spend", text: $fuelSpend)
                        .keyboardType(.decimalPad)
                }

                Section("Garage") {
                    TextField("Search garages", text: $garageSearchQuery)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit { Task { await searchGarages() } }

                    Button {
                        Task { await searchGarages() }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .disabled(trimmedGarageSearchQuery.isEmpty)

                    if isFetchingGarages || isSearchingGarages {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if garageSuggestions.isEmpty {
                        Text("No garages yet. Use search or refresh, or enter custom details below.")
                            .foregroundColor(.secondary)
                    } else {
                        if let label = garageResultsLabel {
                            Text(label)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Each suggestion is its own Form row so hit-testing
                        // works correctly — a VStack of Buttons inside a single
                        // row causes the wrong item to be selected on tap.
                        ForEach(garageSuggestions) { suggestion in
                            Button {
                                selectedGarageID = suggestion.id
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(suggestion.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    if selectedGarageID == suggestion.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                // Make the full row area tappable, not just the text
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button("Refresh Nearby") {
                        Task { await loadGarages() }
                    }

                    TextField("Custom Garage Name", text: $customGarageName)
                    TextField("Details or Address", text: $customGarageDetails)
                        .textInputAutocapitalization(.words)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(existingLog == nil ? "New Log" : "Edit Log")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveLog()
                }
                .disabled(isSaving || (cars.isEmpty && existingLog == nil))
            }
        }
        .task {
            await loadGarages()
        }
        .onAppear {
            if selectedCarRegistration == nil {
                selectedCarRegistration = cars.first?.registration ?? existingLog?.car?.registration
            }
        }
    }

    private var selectedCar: Car? {
        cars.first { $0.registration == selectedCarRegistration }
    }

    private var selectedGarage: GarageSuggestion? {
        guard let selectedGarageID else { return nil }
        return garageSuggestions.first { $0.id == selectedGarageID }
    }

    private var garageResultsLabel: String? {
        if let query = lastGarageSearchQuery, !query.isEmpty {
            return "Results for \"\(query)\""
        } else if !garageSuggestions.isEmpty {
            return "Nearby suggestions"
        }
        return nil
    }

    private var trimmedGarageSearchQuery: String {
        garageSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveLog() {
        guard !isSaving else { return }

        guard let owningUser = user ?? existingLog?.user else {
            errorMessage = "Create a user profile before logging trips."
            return
        }

        guard let car = selectedCar ?? existingLog?.car else {
            errorMessage = "Select a vehicle for this log."
            return
        }

        guard let speedometerValue = parseDecimal(odometerReading) else {
            errorMessage = "Enter a numeric speedometer value."
            return
        }

        guard let distanceValue = parseDecimal(tripDistance) else {
            errorMessage = "Enter a numeric distance value."
            return
        }

        let litersValue = parseDecimal(fuelLiters) ?? 0
        let spendValue = parseDecimal(fuelSpend) ?? 0

        isSaving = true
        defer { isSaving = false }

        if let log = existingLog {
            log.date = date
            log.speedometerKm = speedometerValue
            log.distanceKm = distanceValue
            log.fuelLiters = litersValue
            log.fuelSpend = spendValue
            log.garageName = selectedGarage?.name ?? customGarageName.nonEmpty
            log.garageSubtitle = selectedGarage?.subtitle ?? customGarageDetails.nonEmpty
            log.garageLatitude = selectedGarage?.coordinate.latitude
            log.garageLongitude = selectedGarage?.coordinate.longitude
            log.garageMapItemIdentifier = selectedGarage?.mapItemIdentifier
            log.user = owningUser
            log.car = car
        } else {
            let newLog = LogEntry(
                date: date,
                speedometerKm: speedometerValue,
                distanceKm: distanceValue,
                fuelLiters: litersValue,
                fuelSpend: spendValue,
                garageName: selectedGarage?.name ?? customGarageName.nonEmpty,
                garageSubtitle: selectedGarage?.subtitle ?? customGarageDetails.nonEmpty,
                garageLatitude: selectedGarage?.coordinate.latitude,
                garageLongitude: selectedGarage?.coordinate.longitude,
                garageMapItemIdentifier: selectedGarage?.mapItemIdentifier,
                user: owningUser,
                car: car
            )
            modelContext.insert(newLog)
        }

        do {
            try modelContext.save()
            // Rebuild and persist the widget snapshot so the Home Screen
            // widget updates immediately after every log entry is saved.
            AppDashboardMetricsService.buildAndPersist(using: modelContext)
            dismiss()
        } catch {
            errorMessage = "Unable to save log. Please try again."
        }
    }

    @MainActor
    private func loadGarages() async {
        guard let coordinate = locationManager.lastKnownLocation else {
            garageSuggestions = []
            lastGarageSearchQuery = nil
            return
        }

        isFetchingGarages = true
        defer { isFetchingGarages = false }

        do {
            let fetched = try await garageService.nearbyGarages(around: coordinate)
            garageSuggestions = Array(fetched.prefix(8))
            lastGarageSearchQuery = nil

            if let selection = selectedGarageID,
               garageSuggestions.contains(where: { $0.id == selection }) == false {
                selectedGarageID = nil
            }
        } catch {
            garageSuggestions = []
            lastGarageSearchQuery = nil
            selectedGarageID = nil
        }
    }

    @MainActor
    private func searchGarages() async {
        let query = trimmedGarageSearchQuery
        guard !query.isEmpty else { return }

        isSearchingGarages = true
        defer { isSearchingGarages = false }

        do {
            let fetched = try await garageService.searchGarages(
                matching: query,
                near: locationManager.lastKnownLocation
            )
            garageSuggestions = fetched
            lastGarageSearchQuery = query

            if let selection = selectedGarageID,
               garageSuggestions.contains(where: { $0.id == selection }) == false {
                selectedGarageID = nil
            }
        } catch {
            garageSuggestions = []
            lastGarageSearchQuery = nil
            selectedGarageID = nil
        }
    }

    private func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let number = LogEntryFormView.decimalFormatter.number(from: trimmed) {
            return number.doubleValue
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private static func formattedString(from value: Double?) -> String {
        guard let value else { return "" }
        return LogEntryFormView.decimalFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

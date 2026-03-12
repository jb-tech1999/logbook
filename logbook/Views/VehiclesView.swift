import SwiftUI
import SwiftData
import OSLog

private let vehiclesLogger = Logger(subsystem: "com.jb-tech.logbook", category: "VehiclesView")

// MARK: - VehiclesView

struct VehiclesView: View {
    let onSignOut: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Car.createdAt, order: .reverse)])
    private var cars: [Car]

    @Query(sort: [SortDescriptor(\User.createdAt, order: .reverse)])
    private var users: [User]

    @State private var isPresentingCarForm = false
    @State private var isPresentingProfileSetup = false
    @State private var errorMessage: String?

    private var activeUser: User? { users.first }

    var body: some View {
        List {
            // ── Profile banner ───────────────────────────────────────
            Section {
                if let user = activeUser {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(.headline)
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            isPresentingProfileSetup = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                } else {
                    // No user yet — prompt to create one
                    Button {
                        isPresentingProfileSetup = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Set Up Your Profile")
                                    .font(.headline)
                                Text("Required before adding vehicles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Vehicles ─────────────────────────────────────────────
            if cars.isEmpty {
                Section {
                    Text("No vehicles yet. Tap \"Add Vehicle\" to register your first car.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Section("Registered Vehicles") {
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
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteCars)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Garage")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if activeUser == nil {
                        isPresentingProfileSetup = true
                    } else {
                        isPresentingCarForm = true
                    }
                } label: {
                    Label("Add Vehicle", systemImage: "car.fill")
                }
                Button("Sign Out", role: .destructive, action: onSignOut)
            }
        }
        // Car form sheet
        .sheet(isPresented: $isPresentingCarForm) {
            NavigationStack {
                CarFormView(user: activeUser)
            }
        }
        // Profile setup / edit sheet
        .sheet(isPresented: $isPresentingProfileSetup) {
            NavigationStack {
                ProfileSetupView(existingUser: activeUser)
            }
        }
    }

    private func deleteCars(at offsets: IndexSet) {
        errorMessage = nil

        for index in offsets {
            modelContext.delete(cars[index])
        }

        do {
            try modelContext.save()
        } catch {
            vehiclesLogger.error("Failed to delete vehicle(s): \(error)")
            errorMessage = "Unable to delete vehicle right now. Please try again."
        }
    }
}

// MARK: - ProfileSetupView

struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingUser: User?

    @State private var displayName: String
    @State private var email: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(existingUser: User?) {
        self.existingUser = existingUser
        _displayName = State(initialValue: existingUser?.displayName ?? "")
        _email       = State(initialValue: existingUser?.email ?? "")
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Display Name", text: $displayName)
                    .textContentType(.name)
                    .autocorrectionDisabled()

                TextField("Email Address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Your Details")
            } footer: {
                Text("Used to identify your profile within the app. Not shared externally.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(existingUser == nil ? "Create Profile" : "Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedName  = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()

        guard !trimmedName.isEmpty else {
            errorMessage = "Display name is required."
            return
        }

        errorMessage = nil
        isSaving = true
        defer {
            if errorMessage != nil {
                isSaving = false
            }
        }

        if let user = existingUser {
            user.displayName = trimmedName
            if !trimmedEmail.isEmpty { user.email = trimmedEmail }
        } else {
            let finalEmail = trimmedEmail.isEmpty ? "driver@logbook.app" : trimmedEmail
            let user = User(
                email: finalEmail,
                displayName: trimmedName,
                passwordDigest: "default"
            )
            modelContext.insert(user)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            vehiclesLogger.error("Failed to save profile: \(error)")
            errorMessage = "Could not save profile. Please try again."
        }
    }
}

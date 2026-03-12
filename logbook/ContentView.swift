import SwiftUI
import SwiftData
import OSLog

private let contentLogger = Logger(subsystem: "com.jb-tech.logbook", category: "ContentView")

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("isAuthenticated") private var isAuthenticated = true
    @AppStorage("lastCloudSyncAt") private var lastCloudSyncAt: Double = 0
    @State private var email = ""
    @State private var password = ""
    @State private var isAuthenticating = false
    @State private var authError: String?

 //   private let cloudSyncService = CloudSyncService()
    @State private var isSyncingToCloud = false

    @State private var locationManager = LocationManager()
    @State private var selectedTab: Tab = .dashboard

    var body: some View {
        Group {
            if isAuthenticated {
                TabView(selection: $selectedTab) {

                    NavigationStack {
                        DashboardView(
                            onSignOut: { signOut() }
                        )
                    }
                    .tabItem { Label("Dashboard", systemImage: "speedometer") }
                    .tag(Tab.dashboard)

                    NavigationStack {
                        GarageMapView(
                            locationManager: locationManager,
                            onSignOut: { signOut() }
                        )
                    }
                    .tabItem { Label("Map", systemImage: "map") }
                    .tag(Tab.map)
                    
                    NavigationStack {
                        TripsView()
                    }
                    .tabItem { Label("Trips", systemImage: "map.fill") }
                    .tag(Tab.trips)

                    NavigationStack {
                        LogsView(
                            locationManager: locationManager,
                            onSignOut: { signOut() }
                        )
                    }
                    .tabItem { Label("Logs", systemImage: "list.bullet.rectangle") }
                    .tag(Tab.logs)

                    NavigationStack {
                        VehiclesView(onSignOut: { signOut() })
                    }
                    .tabItem { Label("Garage", systemImage: "car") }
                    .tag(Tab.vehicles)
                }
                .task {
                    // On a fresh install isAuthenticated is already true (AppStorage default),
                    // so the sign-in flow — which normally calls ensureUserRecord — is skipped.
                    // Guard here ensures a default user always exists before any view needs one.
                    ensureUserRecord(for: email.isEmpty ? "driver@logbook.app" : email,
                                     password: "default")
                }
            } else {
                authenticationGate
                    .padding()
            }
        }
        .animation(.easeInOut, value: isAuthenticated)
        //.task {
        //    await maybeSyncToCloud()
        //}
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            //Task { await maybeSyncToCloud() }
        }
    }

    private var authenticationGate: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("Logbook")
                    .bold()
                    .font(.largeTitle)
                Text("Sign in to access your driving metrics and logs.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let authError {
                Text(authError)
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            Button {
                signIn()
            } label: {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(isAuthenticating ? "Signing In" : "Continue")
                        .bold()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)

            Button("Need an account? Contact admin") {}
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private func signIn() {
        authError = nil

        guard isValidEmail(email) else {
            authError = "Enter a valid email address."
            return
        }

        guard password.count >= 6 else {
            authError = "Password must be at least 6 characters."
            return
        }

        isAuthenticating = true

        let currentEmail = email
        let currentPassword = password

        Task {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                contentLogger.error("Sign-in delay task interrupted: \(error)")
            }

            await MainActor.run {
                isAuthenticated = true
                isAuthenticating = false
            }

            await ensureUserRecord(for: currentEmail, password: currentPassword)
        }
    }

    private func signOut() {
        isAuthenticated = false
        email = ""
        password = ""
    }

    private func isValidEmail(_ value: String) -> Bool {
        value.contains("@") && value.contains(".")
    }

    @MainActor
    private func ensureUserRecord(for email: String, password: String) {
        let normalizedEmail = email.lowercased()
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { user in
                user.email == normalizedEmail
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            if !results.isEmpty {
                return
            }
        } catch {
            contentLogger.error("Failed to fetch user records during bootstrap: \(error)")
            authError = "Unable to access your profile right now. Please try again."
            return
        }

        let namePart = email.split(separator: "@").first ?? Substring("Driver")
        let displayName = namePart.isEmpty ? "Driver" : namePart.capitalized

        let user = User(
            email: normalizedEmail,
            displayName: displayName,
            passwordDigest: password
        )

        modelContext.insert(user)

        do {
            try modelContext.save()
        } catch {
            contentLogger.error("Failed to save bootstrapped user record: \(error)")
            authError = "We couldn't save your profile. Please try again."
        }
    }

    // @MainActor
    // private func maybeSyncToCloud() async {
    //     guard isAuthenticated, !isSyncingToCloud else { return }

    //     let now = Date().timeIntervalSince1970
    //     let syncInterval: TimeInterval = 60 * 60 * 24 * 7
    //     guard now - lastCloudSyncAt >= syncInterval else { return }

    //     isSyncingToCloud = true
    //     defer { isSyncingToCloud = false }

    //     do {
    //         try await cloudSyncService.pushAllData(modelContext: modelContext)
    //         lastCloudSyncAt = now
    //     } catch {
    //         print("Cloud sync failed: \(error)")
    //     }
    // }
}

extension ContentView {
    private enum Tab: Hashable {
        case dashboard
        case map
        case trips
        case logs
        case vehicles
    }
}

#Preview {
    ContentView()
}

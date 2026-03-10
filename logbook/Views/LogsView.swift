import SwiftUI
import SwiftData

struct LogsView: View {
    @ObservedObject var locationManager: LocationManager
    let onSignOut: () -> Void

    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\LogEntry.date, order: .reverse)])
    private var logs: [LogEntry]

    @Query(sort: [SortDescriptor(\Car.createdAt, order: .reverse)])
    private var cars: [Car]

    @Query(sort: [SortDescriptor(\User.createdAt, order: .reverse)])
    private var users: [User]

    @State private var isPresentingForm = false
    @State private var logToEdit: LogEntry?

    var body: some View {
        List {
            if logs.isEmpty {
                Section {
                    Text("No logs yet. Tap \"Add Log\" to create your first entry.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(logs) { log in
                    Button {
                        logToEdit = log
                        isPresentingForm = true
                    } label: {
                        LogRow(log: log)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            logToEdit = log
                            isPresentingForm = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: deleteLogs)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()

                Button {
                    logToEdit = nil
                    isPresentingForm = true
                } label: {
                    Label("Add Log", systemImage: "plus")
                }

                Button("Sign Out", role: .destructive, action: onSignOut)
            }
        }
        .sheet(isPresented: $isPresentingForm, onDismiss: { logToEdit = nil }) {
            NavigationStack {
                LogEntryFormView(
                    user: activeUser,
                    cars: cars,
                    locationManager: locationManager,
                    log: logToEdit
                )
            }
        }
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            let log = logs[index]
            context.delete(log)
        }
        do {
            try context.save()
        } catch {
            // Consider surfacing an alert in production
            assertionFailure("Failed to delete logs: \(error)")
        }
    }

    private var activeUser: User? { users.first }
}

private struct LogRow: View {
    let log: LogEntry

    var body: some View {
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
        .contentShape(Rectangle())
    }
}

import SwiftUI
import SwiftData

struct CarFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let user: User?

    @State private var make = "Toyota"
    @State private var model = "Corolla Cross GRS Hybrid"
    @State private var year = "2025"
    @State private var registration = "MF30SWGP"
    @State private var nickname = "CC"
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Vehicle") {
                TextField("Make", text: $make)
                TextField("Model", text: $model)
                TextField("Year", text: $year)
                    .keyboardType(.numberPad)
                TextField("Registration", text: $registration)
                    .textInputAutocapitalization(.characters)
            }

            Section("Details") {
                TextField("Nickname (optional)", text: $nickname)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("New Vehicle")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(isSaving)
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        guard let user else {
            errorMessage = "Create a driver profile before adding vehicles."
            return
        }
        guard !make.isEmpty, !model.isEmpty, !registration.isEmpty else {
            errorMessage = "Make, model, and registration are required."
            return
        }
        guard let numericYear = Int(year), numericYear > 1900 else {
            errorMessage = "Enter a valid year."
            return
        }

        isSaving = true

        let car = Car(
            model: model,
            year: numericYear,
            make: make,
            registration: registration.uppercased(),
            nickname: nickname.isEmpty ? nil : nickname,
            owner: user
        )

        modelContext.insert(car)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Unable to save vehicle."
        }

        isSaving = false
    }
}

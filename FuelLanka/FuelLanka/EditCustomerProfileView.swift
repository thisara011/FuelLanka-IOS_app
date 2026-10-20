import SwiftUI

struct EditCustomerProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let store: CustomerProfileStore
    let userID: String
    let email: String

    @State private var draft = CustomerProfile()
    @State private var original = CustomerProfile()
    @State private var showsDiscardConfirmation = false
    @State private var showsSaveError = false
    @State private var didLoadDraft = false

    private var hasChanges: Bool {
        draft != original
    }

    var body: some View {
        Form {
            if case .failed(let message) = store.state {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section("Personal information") {
                TextField("Full name", text: $draft.fullName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                LabeledContent("Email address", value: email)
                TextField("Phone number", text: $draft.phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                TextField("Preferred district in Sri Lanka", text: $draft.district)
                    .textInputAutocapitalization(.words)
                Text("Email changes require verified account access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            PreferredFuelSection(selection: $draft.preferredFuels)

            Section {
                Toggle("Restock alerts", isOn: $draft.restockAlerts)
                Toggle("Price alerts", isOn: $draft.priceAlerts)
            } header: {
                Text("Notification preferences")
            } footer: {
                Text("These preferences are saved to your account. Device notification permission will be requested when push alerts are connected.")
            }

            Section {
                Button(action: save) {
                    HStack {
                        if store.state == .saving {
                            ProgressView()
                        }
                        Text(store.state == .saving ? "Saving…" : "Save profile")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(!hasChanges || store.state == .saving)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasChanges {
                        showsDiscardConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Profile could not be saved", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            if case .failed(let message) = store.state {
                Text(message)
            } else {
                Text("Check your connection and try again.")
            }
        }
        .task {
            guard !didLoadDraft else { return }
            didLoadDraft = true
            var loadedProfile = store.profile
            loadedProfile.email = email
            draft = loadedProfile
            original = loadedProfile
        }
    }

    private func save() {
        Task {
            var updatedProfile = draft
            updatedProfile.email = email
            if await store.save(updatedProfile, userID: userID) {
                original = updatedProfile
                dismiss()
            } else {
                showsSaveError = true
            }
        }
    }
}

private struct PreferredFuelSection: View {
    @Binding var selection: Set<FuelGrade>

    var body: some View {
        Section("Preferred fuel types") {
            ForEach(FuelGrade.allCases.filter { $0 != .any }) { fuel in
                Toggle(
                    fuel.title,
                    isOn: Binding(
                        get: { selection.contains(fuel) },
                        set: { isSelected in
                            if isSelected {
                                selection.insert(fuel)
                            } else {
                                selection.remove(fuel)
                            }
                        }
                    )
                )
            }
        }
    }
}

#Preview("Edit Customer Profile") {
    NavigationStack {
        EditCustomerProfileView(
            store: CustomerProfileStore(),
            userID: "preview-user",
            email: "customer@example.com"
        )
    }
}

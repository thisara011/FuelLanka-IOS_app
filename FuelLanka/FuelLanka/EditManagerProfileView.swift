import SwiftUI

struct EditManagerProfileView: View {
    let station: StationDetails?
    private let initialName: String
    private let initialPhone: String
    private let email: String?
    private let saveProfile: (String, String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var form: RegistrationForm
    @State private var hasSubmitted = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showsDiscard = false
    @FocusState private var focusedField: RegistrationField?

    init(
        profile: ManagerProfile?,
        station: StationDetails?,
        saveProfile: @escaping (String, String) async throws -> Void = { _, _ in }
    ) {
        self.station = station
        self.saveProfile = saveProfile
        initialName = profile?.fullName ?? ""
        initialPhone = profile?.phone ?? ""
        email = profile?.email
        _form = State(initialValue: RegistrationForm(
            fullName: profile?.fullName ?? "",
            mobile: profile?.phone ?? ""
        ))
    }

    private var hasChanges: Bool {
        form.fullName != initialName || form.mobile != initialPhone
    }

    var body: some View {
        Form {
            Section {
                Text("Keep your contact details current for station alerts.")
                Text("Your changes are saved to your manager account.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Full name") {
                TextField("Full name", text: $form.fullName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .fullName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .mobile }
                if hasSubmitted, let error = form.error(for: .fullName) {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
            Section {
                Text(email ?? "Email unavailable")
                    .textSelection(.enabled)
            } header: {
                Text("Email address")
            } footer: {
                Text("Changing your sign-in email requires verified account access.")
            }
            Section("Phone number") {
                TextField("077 123 4567 or +94 77 123 4567", text: $form.mobile)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .focused($focusedField, equals: .mobile)
                    .accessibilityLabel("Phone number")
                if hasSubmitted, let error = form.error(for: .mobile) {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
            Section {
                Text(station?.name ?? "Assigned station unavailable").font(.headline)
                Text(station?.address ?? "Station address unavailable").foregroundStyle(.secondary)
            } header: {
                Text("Assigned station · read only")
            } footer: {
                Text("Only an administrator can change your station assignment.")
            }
            Section {
                Button("Save changes") { Task { await submit() } }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(!hasChanges)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("WelcomeBackgroundTop"))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit manager profile")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .interactiveDismissDisabled(hasChanges)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasChanges { showsDiscard = true } else { dismiss() }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .confirmationDialog("Discard profile changes?", isPresented: $showsDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Profile update failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Your changes could not be saved.")
        }
    }

    private func submit() async {
        hasSubmitted = true
        for field in [RegistrationField.fullName, .mobile] {
            if form.error(for: field) != nil {
                focusedField = field
                return
            }
        }
        focusedField = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await saveProfile(form.fullName, form.mobile)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Edit Manager Profile") {
    NavigationStack { EditManagerProfileView(profile: nil, station: nil) }
}

import SwiftUI

struct AccountPrivacyView: View {
    let authentication: AuthenticationSession
    let allowsAccountDeletion: Bool

    @State private var password = ""
    @State private var confirmationText = ""
    @State private var showsDeleteConfirmation = false
    @State private var showsDeleteResult = false
    @State private var showsCredentialRemoved = false

    private var account: AuthenticatedAccount? {
        authentication.currentAccount
    }

    private var canSubmitDeletion: Bool {
        confirmationText == "DELETE" &&
            (!((account?.hasPassword) ?? false) || !password.isEmpty)
    }

    var body: some View {
        Form {
            AccountPrivacySummarySection(
                email: account?.email,
                role: account?.role
            )

            DeviceCredentialSection(
                removeCredential: removeBiometricCredential,
                signOut: authentication.signOut
            )

            PrivacyDataSection()

            if allowsAccountDeletion {
                AccountDeletionSection(
                    hasPassword: account?.hasPassword ?? false,
                    password: $password,
                    confirmationText: $confirmationText,
                    isSubmitting: authentication.isSubmitting,
                    canSubmit: canSubmitDeletion,
                    requestDeletion: { showsDeleteConfirmation = true }
                )
            } else {
                Section("Managed administrator account") {
                    Label(
                        "Another administrator must remove or downgrade this account to prevent the project from losing administrative access.",
                        systemImage: "person.badge.shield.checkmark"
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Privacy and account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Permanently delete this account?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete account and data", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your Firebase login, profile, notification records, preferences, favourites, and biometric credential. This cannot be undone.")
        }
        .alert(
            authentication.issue?.title ?? "Account deletion failed",
            isPresented: $showsDeleteResult
        ) {
            Button("OK", role: .cancel) {
                authentication.clearIssue()
            }
        } message: {
            Text(authentication.issue?.message ?? AuthenticationIssue.accountDeletionFailed.message)
        }
        .alert("Biometric credential removed", isPresented: $showsCredentialRemoved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID or Touch ID sign-in is no longer configured on this device.")
        }
        .onDisappear {
            password = ""
            confirmationText = ""
        }
    }

    private func removeBiometricCredential() {
        BiometricCredentialStore().remove()
        showsCredentialRemoved = true
    }

    private func deleteAccount() async {
        let succeeded = await authentication.deleteAccount(
            password: account?.hasPassword == true ? password : nil
        )
        password = ""
        confirmationText = ""
        showsDeleteResult = !succeeded
    }
}

private struct AccountPrivacySummarySection: View {
    let email: String?
    let role: AccountRole?

    var body: some View {
        Section("Current account") {
            LabeledContent("Email", value: email ?? "Unavailable")
            LabeledContent("Authorized role", value: roleTitle)
            Text("Authentication is provided by Firebase. FuelSmart LK stores profile and preference data in Cloud Firestore.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var roleTitle: String {
        switch role {
        case .customer: "Customer"
        case .manager: "Station manager"
        case .administrator: "Administrator"
        case nil: "Unavailable"
        }
    }
}

private struct DeviceCredentialSection: View {
    let removeCredential: () -> Void
    let signOut: () -> Void

    var body: some View {
        Section {
            Button(action: removeCredential) {
                Label("Remove Face ID or Touch ID sign-in", systemImage: "key.slash")
            }
            Button("Sign out on this device", role: .destructive, action: signOut)
        } header: {
            Text("This device")
        } footer: {
            Text("Removing the protected credential does not delete your account. You can continue signing in with another configured method.")
        }
    }
}

private struct PrivacyDataSection: View {
    var body: some View {
        Section {
            Label("Profile and contact information", systemImage: "person.text.rectangle")
            Label("Fuel, district, favourite and alert preferences", systemImage: "slider.horizontal.3")
            Label("Notification tokens and notification history", systemImage: "bell.slash")
        } header: {
            Text("Data included in account deletion")
        } footer: {
            Text("Station sales, deliveries, prices, stock reports and administrator audit records are operational records and are not deleted with a personal account.")
        }
    }
}

private struct AccountDeletionSection: View {
    let hasPassword: Bool
    @Binding var password: String
    @Binding var confirmationText: String
    let isSubmitting: Bool
    let canSubmit: Bool
    let requestDeletion: () -> Void

    var body: some View {
        Section {
            Text("Account deletion is permanent.")
                .font(.headline)
                .foregroundStyle(.red)

            if hasPassword {
                SecureField("Current password", text: $password)
                    .textContentType(.password)
            } else {
                Text("You must have signed in recently with your identity provider.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField("Type DELETE to confirm", text: $confirmationText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            Button("Permanently delete account", role: .destructive) {
                requestDeletion()
            }
            .disabled(!canSubmit || isSubmitting)
        } header: {
            Text("Delete account")
        } footer: {
            Text("For security, password accounts are reauthenticated before deletion.")
        }
    }
}

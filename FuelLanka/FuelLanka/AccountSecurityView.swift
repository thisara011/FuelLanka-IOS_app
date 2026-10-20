import SwiftUI

struct AccountSecurityView: View {
    let authentication: AuthenticationSession
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showsResult = false
    @State private var setupSucceeded = false
    @State private var hasSubmitted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SecurityIntroduction()
                PasswordSetupForm(
                    password: $password,
                    confirmation: $confirmation,
                    hasSubmitted: hasSubmitted,
                    isSubmitting: authentication.isSubmitting,
                    onEnable: enableBiometrics
                )
                PasswordFallbackInformation()

                NavigationLink {
                    ResetPasswordView(returnButtonTitle: "Back to security")
                } label: {
                    Label("Reset password", systemImage: "key")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("security.resetPassword")
            }
            .padding(24)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(Color("WelcomeBackgroundTop"))
        .foregroundStyle(Color("WelcomeHeading"))
        .navigationTitle("Sign-in & security")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .alert(
            setupSucceeded ? "Biometric sign-in enabled" : "Setup failed",
            isPresented: $showsResult
        ) {
            Button("OK", role: .cancel) {
                authentication.clearIssue()
            }
        } message: {
            if setupSucceeded {
                Text("You can now use Face ID or Touch ID from the sign-in screen.")
            } else {
                Text(authentication.issue?.message ?? AuthenticationIssue.unknown.message)
            }
        }
        .onDisappear {
            password = ""
            confirmation = ""
        }
    }

    private func enableBiometrics() {
        hasSubmitted = true
        guard password.count >= 8, password == confirmation else { return }

        Task {
            setupSucceeded = await authentication.enableBiometricSignIn(password: password)
            password = ""
            confirmation = ""
            showsResult = true
        }
    }
}

private struct SecurityIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Biometric sign-in", systemImage: "faceid")
                .font(.headline)
            Text("Create your Firebase password and protect it with Face ID or Touch ID in the iOS Keychain.")
                .font(.subheadline)
                .foregroundStyle(Color("WelcomeSecondary"))
            Text("The credential stays on this device and becomes inaccessible if its enrolled biometrics change.")
                .font(.footnote)
                .foregroundStyle(Color("WelcomeSecondary"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct PasswordSetupForm: View {
    @Binding var password: String
    @Binding var confirmation: String
    let hasSubmitted: Bool
    let isSubmitting: Bool
    let onEnable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Set up secure sign-in")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            SecureField("New password", text: $password)
                .textContentType(.newPassword)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("security.password")

            SecureField("Confirm password", text: $confirmation)
                .textContentType(.newPassword)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("security.passwordConfirmation")

            if hasSubmitted && password.count < 8 {
                Label("Use at least 8 characters.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if hasSubmitted && password != confirmation {
                Label("The passwords do not match.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: onEnable) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                    }
                    Label("Enable Face ID or Touch ID", systemImage: "touchid")
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
            .accessibilityIdentifier("security.enableBiometrics")
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct PasswordFallbackInformation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Password fallback")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Your password remains available when biometrics are cancelled, fail, or are unavailable.")
                .font(.subheadline)
                .foregroundStyle(Color("WelcomeSecondary"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

#Preview("Account Security") {
    NavigationStack {
        AccountSecurityView(authentication: AuthenticationSession())
    }
}

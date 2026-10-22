import SwiftUI

struct CreateAccountView: View {
    let authentication: AuthenticationSession
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var hasSubmitted = false
    @State private var linkSent = false
    @State private var showsAuthenticationIssue = false
    @FocusState private var emailIsFocused: Bool

    var body: some View {
        Form {
            Section {
                Label("Verify your email", systemImage: "envelope.badge.shield.half.filled")
                    .font(.title3)
                    .foregroundStyle(Color("WelcomeHeading"))
                    .accessibilityAddTraits(.isHeader)

                Text("We only need your email to confirm you are a real user. You can complete your profile after signing in.")
                    .font(.subheadline)
                    .foregroundStyle(Color("WelcomeSecondary"))
            }
            .listRowBackground(Color.clear)

            if linkSent {
                confirmationSection
            } else {
                emailSection
            }

            Section {
                VStack(spacing: 12) {
                    Text("Or continue securely")
                        .font(.footnote)
                        .foregroundStyle(Color("WelcomeSecondary"))
                    AppleAuthenticationButton(
                        authentication: authentication,
                        onFailure: { showsAuthenticationIssue = true }
                    )
                }
            }
            .listRowBackground(Color.clear)

            Section {
                Button("Already registered? Sign in") {
                    dismiss()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("registration.signIn")
            }
            .listRowBackground(Color.clear)
        }
        .formStyle(.grouped)
        .listSectionSpacing(16)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background {
            LinearGradient(
                colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .tint(Color("WelcomeAccent"))
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            authentication.issue?.title ?? "Registration failed",
            isPresented: $showsAuthenticationIssue
        ) {
            Button("OK", role: .cancel) {
                authentication.clearIssue()
            }
        } message: {
            Text(authentication.issue?.message ?? AuthenticationIssue.unknown.message)
        }
    }

    @ViewBuilder
    private var emailSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.footnote)
                    .foregroundStyle(Color("WelcomeSecondary"))

                TextField("name@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($emailIsFocused)
                    .onSubmit(sendVerificationLink)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("registration.email")

                if hasSubmitted && !isValidEmail {
                    Label("Enter a valid email address.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        } footer: {
            Text("Firebase will email you a secure, one-time verification link.")
                .foregroundStyle(Color("WelcomeSecondary"))
        }
        .listRowBackground(Color.clear)

        Section {
            Button(action: sendVerificationLink) {
                HStack {
                    if authentication.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(authentication.isSubmitting ? "Sending…" : "Send verification link")
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .disabled(authentication.isSubmitting)
            .accessibilityIdentifier("registration.submit")
        }
        .listRowBackground(Color.clear)
    }

    private var confirmationSection: some View {
        Section {
            ContentUnavailableView {
                Label("Check your email", systemImage: "paperplane.circle.fill")
            } description: {
                Text("We sent a verification link to \(normalizedEmail). Open it on this device to finish registration.")
            } actions: {
                Button("Send again", action: sendVerificationLink)
                    .disabled(authentication.isSubmitting)
                Button("Use a different email") {
                    linkSent = false
                    hasSubmitted = false
                    emailIsFocused = true
                }
            }
        }
        .listRowBackground(Color.clear)
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isValidEmail: Bool {
        let parts = normalizedEmail.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return !parts[0].isEmpty && parts[1].contains(".") && !parts[1].hasSuffix(".")
    }

    private func sendVerificationLink() {
        hasSubmitted = true
        guard isValidEmail else {
            emailIsFocused = true
            return
        }

        emailIsFocused = false
        Task {
            if await authentication.sendRegistrationLink(email: normalizedEmail) {
                linkSent = true
            } else {
                showsAuthenticationIssue = true
            }
        }
    }
}

#Preview("Create Account") {
    NavigationStack {
        CreateAccountView(authentication: AuthenticationSession())
    }
}

#Preview("Create Account Dark") {
    NavigationStack {
        CreateAccountView(authentication: AuthenticationSession())
    }
    .preferredColorScheme(.dark)
}

#Preview("Create Account Large Text") {
    NavigationStack {
        CreateAccountView(authentication: AuthenticationSession())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

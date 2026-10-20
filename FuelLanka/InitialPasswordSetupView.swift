import SwiftUI

struct InitialPasswordSetupView: View {
    let email: String?
    let authentication: AuthenticationSession
    @State private var password = ""
    @State private var confirmation = ""
    @State private var hasSubmitted = false
    @State private var showsIssue = false
    @FocusState private var focusedField: PasswordField?

    fileprivate enum PasswordField {
        case password
        case confirmation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    PasswordSetupHeader(email: email)
                    InitialPasswordFields(
                        password: $password,
                        confirmation: $confirmation,
                        hasSubmitted: hasSubmitted,
                        focusedField: $focusedField,
                        onSubmit: submit
                    )
                    Button(action: submit) {
                        HStack {
                            if authentication.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(authentication.isSubmitting ? "Saving…" : "Create password")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authentication.isSubmitting)
                    .accessibilityIdentifier("passwordSetup.submit")
                }
                .padding(28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background {
                LinearGradient(
                    colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Secure your account")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color("WelcomeAccent"))
        }
        .alert(
            authentication.issue?.title ?? "Password setup failed",
            isPresented: $showsIssue
        ) {
            Button("Try again", role: .cancel) {
                authentication.clearIssue()
            }
        } message: {
            Text(authentication.issue?.message ?? AuthenticationIssue.unknown.message)
        }
        .onDisappear {
            password = ""
            confirmation = ""
        }
    }

    private func submit() {
        hasSubmitted = true
        guard password.count >= 8, password == confirmation else {
            focusedField = password.count < 8 ? .password : .confirmation
            return
        }

        focusedField = nil
        Task {
            let succeeded = await authentication.completePasswordSetup(password: password)
            if !succeeded {
                showsIssue = true
            }
            password = ""
            confirmation = ""
        }
    }
}

private struct PasswordSetupHeader: View {
    let email: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.largeTitle)
                .foregroundStyle(Color("WelcomeAccent"))
                .accessibilityHidden(true)
            Text("Email verified")
                .font(.largeTitle.bold())
                .foregroundStyle(Color("WelcomeHeading"))
                .accessibilityAddTraits(.isHeader)
            if let email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(Color("WelcomeSecondary"))
                    .textSelection(.enabled)
            }
            Text("Create a password for future sign-ins. You can enable Face ID or Touch ID afterward.")
                .font(.subheadline)
                .foregroundStyle(Color("WelcomeSecondary"))
                .multilineTextAlignment(.center)
        }
    }
}

private struct InitialPasswordFields: View {
    @Binding var password: String
    @Binding var confirmation: String
    let hasSubmitted: Bool
    let focusedField: FocusState<InitialPasswordSetupView.PasswordField?>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SecureField("Create password", text: $password)
                .textContentType(.newPassword)
                .submitLabel(.next)
                .focused(focusedField, equals: .password)
                .onSubmit { focusedField.wrappedValue = .confirmation }
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("passwordSetup.password")

            SecureField("Confirm password", text: $confirmation)
                .textContentType(.newPassword)
                .submitLabel(.go)
                .focused(focusedField, equals: .confirmation)
                .onSubmit(onSubmit)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("passwordSetup.confirmation")

            if hasSubmitted && password.count < 8 {
                Label("Use at least 8 characters.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if hasSubmitted && password != confirmation {
                Label("The passwords do not match.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview("Initial Password Setup") {
    InitialPasswordSetupView(
        email: "customer@example.com",
        authentication: AuthenticationSession()
    )
}

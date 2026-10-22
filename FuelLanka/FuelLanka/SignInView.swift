import SwiftUI

struct SignInView: View {
    let authentication: AuthenticationSession
    @State private var email = ""
    @State private var password = ""
    @State private var hasSubmitted = false
    @State private var showsAuthenticationIssue = false
    @FocusState private var focusedField: Field?

    fileprivate enum Field: Hashable {
        case email
        case password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                SignInHeader()
                SignInCredentials(
                    email: $email,
                    password: $password,
                    hasSubmitted: hasSubmitted,
                    focusedField: $focusedField,
                    onSubmit: submit
                )
                SignInControls(
                    isSubmitting: authentication.isSubmitting,
                    onPasswordSignIn: submit,
                    onBiometricSignIn: signInWithBiometrics
                )
                FederatedSignInSection(
                    authentication: authentication,
                    onFailure: { showsAuthenticationIssue = true }
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 44)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            LinearGradient(
                colors: [Color("WelcomeBackgroundTop"), Color("WelcomeBackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("WelcomeAccent"))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .alert(
            authentication.issue?.title ?? "Authentication failed",
            isPresented: $showsAuthenticationIssue
        ) {
            Button("OK", role: .cancel) {
                authentication.clearIssue()
            }
        } message: {
            Text(authentication.issue?.message ?? AuthenticationIssue.unknown.message)
        }
        .onDisappear {
            password = ""
        }
    }

    private func signInWithBiometrics() {
        focusedField = nil
        Task {
            let succeeded = await authentication.signInWithBiometrics()
            showsAuthenticationIssue = !succeeded
        }
    }

    private func submit() {
        hasSubmitted = true
        if SignInValidation.emailError(for: email) != nil {
            focusedField = .email
        } else if SignInValidation.passwordError(for: password) != nil {
            focusedField = .password
        } else {
            focusedField = nil
            Task {
                await authentication.signIn(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                password = ""
                showsAuthenticationIssue = authentication.issue != nil
            }
        }
    }
}

private struct SignInHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "fuelpump.fill")
                .font(.largeTitle)
                .foregroundStyle(Color("WelcomeAccent"))
                .accessibilityHidden(true)
            Text("Welcome back")
                .font(.largeTitle.bold())
                .foregroundStyle(Color("WelcomeHeading"))
                .accessibilityAddTraits(.isHeader)
            Text("Sign in to continue to FuelSmart LK")
                .font(.subheadline)
                .foregroundStyle(Color("WelcomeSecondary"))
        }
        .multilineTextAlignment(.center)
    }
}

private struct SignInCredentials: View {
    @Binding var email: String
    @Binding var password: String
    let hasSubmitted: Bool
    let focusedField: FocusState<SignInView.Field?>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            SignInField(symbol: "person", title: "Email") {
                TextField("name@example.com", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused(focusedField, equals: .email)
                    .onSubmit { focusedField.wrappedValue = .password }
                    .accessibilityIdentifier("signIn.email")
            }

            if hasSubmitted, let error = SignInValidation.emailError(for: email) {
                SignInFieldError(message: error)
            }

            SignInField(symbol: "lock", title: "Password") {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .focused(focusedField, equals: .password)
                    .onSubmit(onSubmit)
                    .accessibilityIdentifier("signIn.password")
            }

            if hasSubmitted, let error = SignInValidation.passwordError(for: password) {
                SignInFieldError(message: error)
            }

            NavigationLink(value: AuthenticationRoute.resetPassword) {
                Text("Forgot Password?")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
            }
            .accessibilityIdentifier("signIn.forgotPassword")
        }
    }
}

private struct SignInField<Content: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(Color("WelcomeSecondary"))
                .accessibilityHidden(true)
            content
                .frame(minHeight: 48)
                .accessibilityLabel(Text(title))
        }
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground).opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color("WelcomeSecondary").opacity(0.35))
                .frame(height: 1)
        }
    }
}

private struct SignInControls: View {
    private let biometricType = BiometricCredentialStore().biometricType

    let isSubmitting: Bool
    let onPasswordSignIn: () -> Void
    let onBiometricSignIn: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ViewThatFits {
                HStack(spacing: 22) {
                    biometricButtons
                    signInButton
                }
                VStack(spacing: 16) {
                    HStack(spacing: 28) {
                        biometricButtons
                    }
                    signInButton
                }
            }

            NavigationLink(value: AuthenticationRoute.createAccount) {
                Text("New to FuelSmart LK? Create account")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("signIn.createAccount")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var biometricButtons: some View {
        if biometricType != .unavailable {
            BiometricButton(
                title: LocalizedStringKey(biometricType.title),
                systemImage: biometricType.systemImage,
                action: onBiometricSignIn
            )
        }
    }

    private var signInButton: some View {
        Button(action: onPasswordSignIn) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSubmitting ? "Signing in…" : "Sign in")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 28)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.70, green: 0.10, blue: 0.17),
                        Color(red: 0.45, green: 0.12, blue: 0.35)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .disabled(isSubmitting)
        .accessibilityIdentifier("signIn.submit")
    }
}

private struct BiometricButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.largeTitle, design: .rounded))
                .frame(width: 54, height: 54)
                .foregroundStyle(Color("WelcomeHeading"))
        }
        .accessibilityLabel(title)
        .accessibilityHint("Requires biometric setup after password sign-in")
    }
}

private struct SignInFieldError: View {
    let message: LocalizedStringResource

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.circle")
        }
        .font(.footnote)
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Sign In") {
    NavigationStack {
        SignInView(authentication: AuthenticationSession())
    }
}

#Preview("Sign In Dark") {
    NavigationStack {
        SignInView(authentication: AuthenticationSession())
    }
    .preferredColorScheme(.dark)
}

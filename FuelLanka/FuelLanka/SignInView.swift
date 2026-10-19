import SwiftUI

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var hasSubmitted = false
    @State private var showsServiceNotice = false
    @State private var showsBiometricNotice = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
    }

    var body: some View {
        Form {
            Section {
                SignInHeader()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 7, bottom: 16, trailing: 7))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("WelcomeSecondary"))
                    TextField("name@example.com", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .accessibilityLabel("Email")
                        .accessibilityIdentifier("signIn.email")
                        .frame(minHeight: 44)
                        .onSubmit { focusedField = .password }
                    if hasSubmitted, let error = SignInValidation.emailError(for: email) {
                        SignInFieldError(message: error)
                    }
                }
                .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("WelcomeSecondary"))
                    SecureField("Enter your password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .password)
                        .accessibilityLabel("Password")
                        .accessibilityIdentifier("signIn.password")
                        .frame(minHeight: 44)
                        .onSubmit(submit)
                    if hasSubmitted, let error = SignInValidation.passwordError(for: password) {
                        SignInFieldError(message: error)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)

            Section {
                NavigationLink(value: AuthenticationRoute.resetPassword) {
                    Text("Forgot password?")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color("WelcomeAccent"))
                .listRowBackground(Color.clear)
            }
            .listSectionSpacing(8)

            Section {
                SignInActions(
                    onPasswordSignIn: submit,
                    onFaceIDSignIn: { showsBiometricNotice = true }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            .listSectionSpacing(16)

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
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(Color("WelcomeAccent"))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .alert("Sign-in service not connected", isPresented: $showsServiceNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign-in is not available yet. Your credentials have not been sent.")
        }
        .alert("Sign in with your password first", isPresented: $showsBiometricNotice) {
            Button("Use password", role: .cancel) { focusedField = .email }
        } message: {
            Text("Face ID will be available to returning customers after signing in and choosing to enable it. Face ID is not available yet.")
        }
        .onDisappear {
            password = ""
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
            password = ""
            hasSubmitted = false
            showsServiceNotice = true
        }
    }
}

private struct SignInHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Welcome back")
                .font(.title.bold())
                .tracking(-0.6)
                .foregroundStyle(Color("WelcomeHeading"))
                .accessibilityAddTraits(.isHeader)
            Text("Use password or Face ID to continue")
                .font(.subheadline)
                .foregroundStyle(Color("WelcomeSecondary"))
        }
        .fixedSize(horizontal: false, vertical: true)
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
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SignInActions: View {
    let onPasswordSignIn: () -> Void
    let onFaceIDSignIn: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onPasswordSignIn) {
                Text("Sign in with password")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.horizontal, 16)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.161, green: 0.486, blue: 0.902),
                                Color(red: 0.078, green: 0.314, blue: 0.780)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: Capsule()
                    )
            }
            .accessibilityIdentifier("signIn.submit")

            Button(action: onFaceIDSignIn) {
                Text("Sign in with Face ID")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            }
            .accessibilityIdentifier("signIn.faceID")

            NavigationLink(value: AuthenticationRoute.createAccount) {
                Text("New to FuelSmart?   Create account")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("signIn.createAccount")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color("WelcomeAccent"))
    }
}

#Preview("Sign In") {
    NavigationStack {
        SignInView()
    }
}

#Preview("Sign In Dark") {
    NavigationStack {
        SignInView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Sign In Large Text") {
    NavigationStack {
        SignInView()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

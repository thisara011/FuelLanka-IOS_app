import SwiftUI

struct CreateAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var form = RegistrationForm()
    @State private var hasSubmitted = false
    @State private var showsServiceNotice = false
    @State private var showsPolicyNotice = false
    @FocusState private var focusedField: RegistrationField?

    var body: some View {
        Form {
            Section {
                Text("Create your customer account")
                    .font(.title3)
                    .foregroundStyle(Color("WelcomeHeading"))
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)
            }

            Section {
                RegistrationRow(title: "Full name", error: hasSubmitted ? form.error(for: .fullName) : nil) {
                    TextField("Your full name", text: $form.fullName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .fullName)
                        .onSubmit { focusedField = .email }
                        .accessibilityIdentifier("registration.name")
                }
                RegistrationRow(title: "Email", error: hasSubmitted ? form.error(for: .email) : nil) {
                    TextField("name@example.com", text: $form.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .mobile }
                        .accessibilityIdentifier("registration.email")
                }
                RegistrationRow(title: "Mobile", error: hasSubmitted ? form.error(for: .mobile) : nil) {
                    TextField("+94 77 123 4567", text: $form.mobile)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .mobile)
                        .accessibilityIdentifier("registration.mobile")
                }
                RegistrationRow(title: "Password", error: hasSubmitted ? form.error(for: .password) : nil) {
                    SecureField("At least 8 characters", text: $form.password)
                        .textContentType(.newPassword)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .password)
                        .onSubmit { focusedField = .confirmation }
                        .accessibilityIdentifier("registration.password")
                }
                RegistrationRow(title: "Confirm password", error: hasSubmitted ? form.error(for: .confirmation) : nil) {
                    SecureField("Re-enter your password", text: $form.confirmation)
                        .textContentType(.newPassword)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .confirmation)
                        .onSubmit(submit)
                        .accessibilityIdentifier("registration.confirmation")
                }
            } footer: {
                Text("Use at least 8 characters for your password.")
                    .foregroundStyle(Color("WelcomeSecondary"))
            }
            .listRowBackground(Color.clear)

            Section {
                Toggle("I agree to the Terms and Privacy Policy", isOn: $form.acceptsTerms)
                    .font(.subheadline)
                    .accessibilityIdentifier("registration.terms")
                Button("Terms and Privacy Policy") {
                    showsPolicyNotice = true
                }
                .font(.footnote)
                if hasSubmitted && !form.acceptsTerms {
                    Text("Please agree to the Terms and Privacy Policy to continue.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .listRowBackground(Color.clear)

            Section {
                RegistrationActions(onCreate: submit, onSignIn: { dismiss() })
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
            } footer: {
                Text("FuelSmart LK")
                    .font(.caption2)
                    .frame(maxWidth: .infinity)
            }
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
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField == .mobile {
                    Button("Next") { focusedField = .password }
                }
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .alert("Registration service not connected", isPresented: $showsServiceNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Registration is not available yet. Your details have not been sent and no account has been created.")
        }
        .alert("Policies are not available yet", isPresented: $showsPolicyNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The Terms and Privacy Policy will be available before registration is enabled.")
        }
        .onDisappear { form.clearPasswords() }
    }

    private func submit() {
        hasSubmitted = true
        if let invalidField = form.firstInvalidField {
            focusedField = invalidField
        } else {
            focusedField = nil
            guard form.canSubmit else { return }
            form.clearPasswords()
            hasSubmitted = false
            showsServiceNotice = true
        }
    }
}

private struct RegistrationRow<Content: View>: View {
    let title: LocalizedStringKey
    let error: LocalizedStringResource?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Color("WelcomeSecondary"))
            content
                .frame(minHeight: 44)
                .accessibilityLabel(Text(title))
            if let error {
                Label {
                    Text(error)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct RegistrationActions: View {
    let onCreate: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onCreate) {
                Text("Create account")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .padding(.horizontal, 18)
                    .foregroundStyle(.white)
                    .background(Color(red: 0.071, green: 0.380, blue: 0.839), in: Capsule())
            }
            .accessibilityIdentifier("registration.submit")
            Button("Already registered? Sign in", action: onSignIn)
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("registration.signIn")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color("WelcomeAccent"))
    }
}

#Preview("Create Account") {
    NavigationStack { CreateAccountView() }
}

#Preview("Create Account Dark") {
    NavigationStack { CreateAccountView() }
        .preferredColorScheme(.dark)
}

#Preview("Create Account Large Text") {
    NavigationStack { CreateAccountView() }
        .environment(\.dynamicTypeSize, .accessibility3)
}

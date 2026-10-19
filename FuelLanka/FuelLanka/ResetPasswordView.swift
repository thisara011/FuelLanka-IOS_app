import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var hasSubmitted = false
    @State private var showsServiceNotice = false
    @FocusState private var emailIsFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Recover your account")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color("WelcomeHeading"))
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 3, bottom: 12, trailing: 3))
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email address")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("WelcomeHeading"))
                    TextField("name@example.com", text: $email)
                        .font(.subheadline)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .focused($emailIsFocused)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Email address")
                        .accessibilityIdentifier("reset.email")
                        .onSubmit(submit)
                    if hasSubmitted, let error = SignInValidation.emailError(for: email) {
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
                .padding(.vertical, 4)
            }

            Section {
                Button(action: submit) {
                    Text("Send reset link")
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, minHeight: 49, alignment: .leading)
                        .padding(.horizontal, 17)
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
                .buttonStyle(.plain)
                .accessibilityIdentifier("reset.submit")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            Section {
                ResetPasswordStatus()
            } footer: {
                Text("FuelSmart LK")
                    .font(.caption2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            }
        }
        .formStyle(.grouped)
        .listSectionSpacing(14)
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
        .navigationTitle("Reset password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(Color("WelcomeAccent"))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { emailIsFocused = false }
            }
        }
        .alert("Reset service not connected", isPresented: $showsServiceNotice) {
            Button("Back to sign in") { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("No reset email has been sent. Your email passed the local format check, but account recovery will be available when the authentication service is connected.")
        }
    }

    private func submit() {
        hasSubmitted = true
        guard SignInValidation.emailError(for: email) == nil else {
            emailIsFocused = true
            return
        }
        emailIsFocused = false
        showsServiceNotice = true
    }
}

private struct ResetPasswordStatus: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account recovery")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("WelcomeHeading"))
            Text("Password recovery is not available yet. No reset email will be sent.")
                .font(.footnote)
                .foregroundStyle(Color("WelcomeSecondary"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Reset Password") {
    NavigationStack { ResetPasswordView() }
}

#Preview("Reset Password Dark") {
    NavigationStack { ResetPasswordView() }
        .preferredColorScheme(.dark)
}

#Preview("Reset Password Large Text") {
    NavigationStack { ResetPasswordView() }
        .environment(\.dynamicTypeSize, .accessibility3)
}

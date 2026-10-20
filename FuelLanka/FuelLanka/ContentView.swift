import SwiftUI

enum WelcomeRoute: Hashable {
    case signIn
    case returningCustomer
}

enum AuthenticationRoute: Hashable {
    case createAccount
    case resetPassword
}

struct ContentView: View {
    let authentication: AuthenticationSession

    var body: some View {
        Group {
            switch authentication.status {
            case .checking:
                ProgressView("Checking your session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                AuthenticationFlow(authentication: authentication)
            case .passwordSetup(let account):
                InitialPasswordSetupView(
                    email: account.email,
                    authentication: authentication
                )
            case .authenticated(let account):
                AuthorizedWorkspace(account: account, authentication: authentication)
            case .blocked(let issue):
                BlockedAccountView(issue: issue, authentication: authentication)
            }
        }
        .task {
            if authentication.status == .checking {
                await authentication.restore()
            }
        }
        .onOpenURL { url in
            Task {
                await authentication.handleIncomingURL(url)
            }
        }
    }
}

private struct AuthenticationFlow: View {
    let authentication: AuthenticationSession

    var body: some View {
        NavigationStack {
            WelcomeView()
                .navigationDestination(for: WelcomeRoute.self) { route in
                    // Password sign-in remains the fallback until biometric opt-in is implemented.
                    SignInView(authentication: authentication)
                }
                .navigationDestination(for: AuthenticationRoute.self) { route in
                    switch route {
                    case .createAccount:
                        CreateAccountView(authentication: authentication)
                    case .resetPassword:
                        ResetPasswordView(authentication: authentication)
                    }
                }
        }
        .tint(Color("WelcomeAccent"))
    }
}

private struct AuthorizedWorkspace: View {
    let account: AuthenticatedAccount
    let authentication: AuthenticationSession

    var body: some View {
        switch account.role {
        case .customer:
            CustomerWorkspaceView(authentication: authentication)
        case .manager:
            ManagerWorkspaceView(authentication: authentication)
        case .administrator:
            AdministratorWorkspaceView(authentication: authentication)
        }
    }
}

private struct BlockedAccountView: View {
    let issue: AuthenticationIssue
    let authentication: AuthenticationSession

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(issue.title, systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                Text(issue.message)
            } actions: {
                Button("Return to sign in") {
                    authentication.signOut()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Account access")
        }
        .tint(Color("WelcomeAccent"))
    }
}

#Preview("Welcome") {
    ContentView(authentication: AuthenticationSession())
}

#Preview("Dark") {
    ContentView(authentication: AuthenticationSession())
        .preferredColorScheme(.dark)
}

#Preview("Accessibility") {
    ContentView(authentication: AuthenticationSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}

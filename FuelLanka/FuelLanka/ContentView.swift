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
    var body: some View {
        NavigationStack {
            WelcomeView()
                .navigationDestination(for: WelcomeRoute.self) { route in
                    // Password sign-in remains the fallback until biometric opt-in is implemented.
                    SignInView()
                }
                .navigationDestination(for: AuthenticationRoute.self) { route in
                    switch route {
                    case .createAccount:
                        CreateAccountView()
                    case .resetPassword:
                        ResetPasswordView()
                    }
                }
        }
        .tint(Color("WelcomeAccent"))
    }
}

#Preview("Welcome") {
    ContentView()
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("iPad layout", traits: .fixedLayout(width: 1024, height: 768)) {
    ContentView()
}

#Preview("Accessibility") {
    ContentView()
        .environment(\.dynamicTypeSize, .accessibility3)
}

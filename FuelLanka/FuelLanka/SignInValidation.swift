import Foundation

/// Local input checks only. Account existence and credentials are verified by the auth service.
enum SignInValidation {
    static func emailError(for email: String) -> LocalizedStringResource? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return "Enter your email address."
        }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              parts[1].contains("."),
              !parts[1].hasPrefix("."),
              !parts[1].hasSuffix("."),
              !value.contains(where: { $0.isWhitespace }) else {
            return "Enter an email address such as name@example.com."
        }
        return nil
    }

    static func passwordError(for password: String) -> LocalizedStringResource? {
        // Sign-in must accept existing passwords without imposing a new registration policy.
        password.isEmpty ? "Enter your password." : nil
    }
}

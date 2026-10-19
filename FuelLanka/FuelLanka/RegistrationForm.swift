import Foundation

enum RegistrationField: Hashable {
    case fullName, email, mobile, password, confirmation
}

struct RegistrationForm {
    var fullName = ""
    var email = ""
    var mobile = ""
    var password = ""
    var confirmation = ""
    var acceptsTerms = false

    func error(for field: RegistrationField) -> LocalizedStringResource? {
        switch field {
        case .fullName:
            return fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Enter your full name." : nil
        case .email:
            return SignInValidation.emailError(for: email)
        case .mobile:
            let compact = mobile.filter { !" ()-".contains($0) }
            let digits = compact.hasPrefix("+") ? String(compact.dropFirst()) : compact
            let containsOnlyDigits = !digits.isEmpty && digits.allSatisfy { $0 >= "0" && $0 <= "9" }
            let validLength = compact.hasPrefix("+")
                ? (8...15).contains(digits.count) && !digits.hasPrefix("0")
                : digits.count == 10 && digits.hasPrefix("07")
            return containsOnlyDigits && validLength ? nil
                : "Enter a mobile number such as 077 123 4567 or +94 77 123 4567."
        case .password:
            return password.count >= 8 && !password.allSatisfy({ $0.isWhitespace })
                ? nil : "Use at least 8 characters for your password."
        case .confirmation:
            return !confirmation.isEmpty && confirmation == password
                ? nil : "Enter the same password in both fields."
        }
    }

    var firstInvalidField: RegistrationField? {
        [RegistrationField.fullName, .email, .mobile, .password, .confirmation]
            .first { error(for: $0) != nil }
    }

    var canSubmit: Bool {
        firstInvalidField == nil && acceptsTerms
    }

    mutating func clearPasswords() {
        password = ""
        confirmation = ""
    }
}

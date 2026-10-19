import Testing
@testable import FuelLanka

struct SignInValidationTests {
    @Test(arguments: ["", "   ", "person", "@example.com", "person@", "person@@example.com", "person@.com", "person@example.", "person name@example.com"])
    func rejectsIncompleteEmail(_ email: String) {
        #expect(SignInValidation.emailError(for: email) != nil)
    }

    @Test(arguments: ["person@example.com", " person@example.com\n", "person+fuel@example.co.uk"])
    func acceptsCommonEmailForms(_ email: String) {
        #expect(SignInValidation.emailError(for: email) == nil)
    }

    @Test func requiresPasswordWithoutApplyingRegistrationPolicy() {
        #expect(SignInValidation.passwordError(for: "") != nil)
        #expect(SignInValidation.passwordError(for: "short") == nil)
        // Password whitespace is meaningful; never trim credentials during sign-in.
        #expect(SignInValidation.passwordError(for: " secret ") == nil)
    }
}

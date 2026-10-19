import Testing
@testable import FuelLanka

struct RegistrationFormTests {
    private func validForm() -> RegistrationForm {
        RegistrationForm(fullName: "Nimal", email: "nimal@example.com", mobile: "077 123 4567",
                         password: "password123", confirmation: "password123", acceptsTerms: true)
    }

    @Test func requiresAllFieldsAndConsent() {
        #expect(RegistrationForm().firstInvalidField == .fullName)
        var form = validForm()
        #expect(form.canSubmit)
        form.acceptsTerms = false
        #expect(!form.canSubmit)
        form.fullName = "  \n"
        #expect(form.firstInvalidField == .fullName)
    }

    @Test(arguments: ["0771234567", "+94 77 123 4567", "+44 7700 900123"])
    func acceptsMobileFormats(_ mobile: String) {
        var form = validForm()
        form.mobile = mobile
        #expect(form.error(for: .mobile) == nil)
    }

    @Test(arguments: ["", "077abc4567", "+00000000", "1234", "077123456789", "0771234567\n"])
    func rejectsMalformedMobile(_ mobile: String) {
        var form = validForm()
        form.mobile = mobile
        #expect(form.error(for: .mobile) != nil)
    }

    @Test func checksPasswordLengthAndExactConfirmation() {
        var form = validForm()
        form.password = "1234567"
        #expect(form.error(for: .password) != nil)
        form.password = "        "
        #expect(form.error(for: .password) != nil)
        form.password = " secret "
        form.confirmation = "secret"
        #expect(form.error(for: .password) == nil)
        #expect(form.error(for: .confirmation) != nil)
        form.confirmation = form.password
        #expect(form.canSubmit)
        form.clearPasswords()
        #expect(form.password.isEmpty && form.confirmation.isEmpty)
        #expect(!form.canSubmit)
    }
}

import Foundation
import Testing
@testable import FuelLanka

@MainActor
struct AuthenticationSessionTests {
    @Test func restoresAuthorizedRole() async {
        let account = AuthenticatedAccount(
            id: "user",
            email: "customer@example.com",
            role: .customer,
            hasPassword: true
        )
        let session = AuthenticationSession(service: FakeAuthenticationService(account: account))

        await session.restore()

        #expect(session.status == .authenticated(account))
        #expect(session.issue == nil)
    }

    @Test func restoresManagerRole() async {
        let account = AuthenticatedAccount(
            id: "manager",
            email: "manager@example.com",
            role: .manager,
            hasPassword: true
        )
        let session = AuthenticationSession(service: FakeAuthenticationService(account: account))

        await session.restore()

        #expect(session.status == .authenticated(account))
        #expect(session.currentAccount?.role == .manager)
    }

    @Test func restoresAdministratorRole() async {
        let account = AuthenticatedAccount(
            id: "administrator",
            email: "admin@example.com",
            role: .administrator,
            hasPassword: true
        )
        let session = AuthenticationSession(service: FakeAuthenticationService(account: account))

        await session.restore()

        #expect(session.status == .authenticated(account))
        #expect(session.currentAccount?.role == .administrator)
    }

    @Test func passwordlessAccountMustCreatePasswordBeforeWorkspace() async {
        let account = AuthenticatedAccount(
            id: "passwordless-user",
            email: "new@example.com",
            role: .customer,
            hasPassword: false
        )
        let session = AuthenticationSession(service: FakeAuthenticationService(account: account))

        await session.restore()
        #expect(session.status == .passwordSetup(account))

        let succeeded = await session.completePasswordSetup(password: "secure-password")
        #expect(succeeded)
        #expect(
            session.status == .authenticated(
                AuthenticatedAccount(
                    id: account.id,
                    email: account.email,
                    role: account.role,
                    hasPassword: true
                )
            )
        )
    }

    @Test func passwordlessAppleAccountMustCreatePasswordBeforeWorkspace() async {
        let account = AuthenticatedAccount(
            id: "apple-user",
            email: "apple@example.com",
            role: .customer,
            hasPassword: false
        )
        let session = AuthenticationSession(service: FakeAuthenticationService(account: account))

        let succeeded = await session.signInWithApple(
            idToken: "token",
            rawNonce: "nonce",
            fullName: nil
        )

        #expect(succeeded)
        #expect(session.status == .passwordSetup(account))
    }

    @Test func missingConfigurationReturnsToSignedOutState() async {
        let session = AuthenticationSession(
            service: FakeAuthenticationService(failure: .configurationMissing)
        )

        await session.restore()

        #expect(session.status == .signedOut)
        #expect(session.issue == .configurationMissing)
    }

    @Test func unauthorizedRoleBlocksWorkspace() async {
        let service = FakeAuthenticationService(failure: .unauthorizedRole)
        let session = AuthenticationSession(service: service)

        await session.signIn(email: "user@example.com", password: "password")

        #expect(session.status == .blocked(.unauthorizedRole))
        #expect(session.issue == .unauthorizedRole)
        #expect(!session.isSubmitting)
    }

    @Test func registrationLinkCompletesCustomerSession() async {
        let account = AuthenticatedAccount(
            id: "new-user",
            email: "new@example.com",
            role: .customer,
            hasPassword: true
        )
        let service = FakeAuthenticationService(account: account)
        let session = AuthenticationSession(service: service)
        await session.restore()

        let sent = await session.sendRegistrationLink(email: "new@example.com")
        await session.handleIncomingURL(URL(string: "https://fuelsmart-lk.firebaseapp.com/finishSignUp")!)

        #expect(sent)
        #expect(service.registrationLinkRequests == ["new@example.com"])
        #expect(session.status == .authenticated(account))
        #expect(session.issue == nil)
    }

    @Test func passwordResetReportsSuccessWithoutChangingSession() async {
        let service = FakeAuthenticationService(account: nil)
        let session = AuthenticationSession(service: service)
        await session.restore()

        let succeeded = await session.sendPasswordReset(email: "user@example.com")

        #expect(succeeded)
        #expect(session.status == .signedOut)
        #expect(service.resetRequests == ["user@example.com"])
    }

    @Test func deletingAccountSignsOutAndForwardsPassword() async {
        let account = AuthenticatedAccount(
            id: "delete-user",
            email: "delete@example.com",
            role: .customer,
            hasPassword: true
        )
        let service = FakeAuthenticationService(account: account)
        let session = AuthenticationSession(service: service)
        await session.restore()

        let succeeded = await session.deleteAccount(password: "confirmed-password")

        #expect(succeeded)
        #expect(session.status == .signedOut)
        #expect(session.issue == nil)
        #expect(service.deletionPasswords == ["confirmed-password"])
    }

    @Test func failedAccountDeletionKeepsTheAuthenticatedSession() async {
        let account = AuthenticatedAccount(
            id: "retained-user",
            email: "retained@example.com",
            role: .customer,
            hasPassword: true
        )
        let service = FakeAuthenticationService(account: account, deletionFailure: .invalidCredentials)
        let session = AuthenticationSession(service: service)
        await session.restore()

        let succeeded = await session.deleteAccount(password: "incorrect-password")

        #expect(!succeeded)
        #expect(session.status == .authenticated(account))
        #expect(session.issue == .invalidCredentials)
    }
}

@MainActor
private final class FakeAuthenticationService: AuthenticationService {
    private let account: AuthenticatedAccount?
    private let failure: AuthenticationIssue?
    private let deletionFailure: AuthenticationIssue?
    private(set) var resetRequests: [String] = []
    private(set) var registrationLinkRequests: [String] = []
    private(set) var deletionPasswords: [String?] = []

    init(account: AuthenticatedAccount?, deletionFailure: AuthenticationIssue? = nil) {
        self.account = account
        self.deletionFailure = deletionFailure
        failure = nil
    }

    init(failure: AuthenticationIssue) {
        account = nil
        deletionFailure = nil
        self.failure = failure
    }

    func restoreAccount() async throws -> AuthenticatedAccount? {
        try result()
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedAccount {
        guard let account = try result() else {
            throw AuthenticationIssue.invalidCredentials
        }
        return account
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedAccount {
        guard let account = try result() else {
            throw AuthenticationIssue.roleNotAssigned
        }
        return account
    }

    func registerCustomer(email: String, password: String) async throws -> AuthenticatedAccount {
        guard let account = try result() else {
            throw AuthenticationIssue.roleNotAssigned
        }
        return account
    }

    func sendRegistrationLink(email: String) async throws {
        if let failure {
            throw failure
        }
        registrationLinkRequests.append(email)
    }

    func completeRegistrationLink(_ url: URL) async throws -> AuthenticatedAccount {
        guard let account = try result() else {
            throw AuthenticationIssue.invalidRegistrationLink
        }
        return account
    }

    func updatePassword(_ password: String) async throws {
        if let failure {
            throw failure
        }
    }

    func sendPasswordReset(email: String) async throws {
        if let failure {
            throw failure
        }
        resetRequests.append(email)
    }

    func deleteCurrentAccount(password: String?) async throws {
        deletionPasswords.append(password)
        if let deletionFailure {
            throw deletionFailure
        }
    }

    func signOut() throws {}

    private func result() throws -> AuthenticatedAccount? {
        if let failure {
            throw failure
        }
        return account
    }
}

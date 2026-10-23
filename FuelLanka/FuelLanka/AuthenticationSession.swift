import Foundation
import Observation

#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseFirestore
#endif

enum AccountRole: String, Equatable, Sendable {
    case customer
    case manager
    case administrator = "admin"
}

struct AuthenticatedAccount: Equatable, Sendable {
    let id: String
    let email: String?
    let role: AccountRole
    let hasPassword: Bool
}

enum AuthenticationIssue: Error, Equatable, Sendable {
    case configurationMissing
    case invalidCredentials
    case emailAlreadyInUse
    case emailNotVerified
    case weakPassword
    case networkUnavailable
    case emailQuotaExceeded
    case biometricsUnavailable
    case biometricsNotConfigured
    case biometricAuthenticationCancelled
    case biometricCredentialFailure
    case invalidRegistrationLink
    case emailLinkNotEnabled
    case invalidContinueURL
    case missingRegistrationEmail
    case roleNotAssigned
    case unauthorizedRole
    case accountDeletionFailed
    case unknown

    var title: LocalizedStringResource {
        switch self {
        case .configurationMissing: "Firebase not configured"
        case .invalidCredentials: "Unable to sign in"
        case .emailAlreadyInUse: "Email already registered"
        case .emailNotVerified: "Verify your email"
        case .weakPassword: "Password not accepted"
        case .networkUnavailable: "Network unavailable"
        case .emailQuotaExceeded: "Daily email limit reached"
        case .biometricsUnavailable: "Biometrics unavailable"
        case .biometricsNotConfigured: "Biometric setup required"
        case .biometricAuthenticationCancelled: "Biometric sign-in cancelled"
        case .biometricCredentialFailure: "Biometric credential unavailable"
        case .invalidRegistrationLink: "Verification link not accepted"
        case .emailLinkNotEnabled: "Email-link sign-in is disabled"
        case .invalidContinueURL: "Email-link domain is not authorized"
        case .missingRegistrationEmail: "Enter your email again"
        case .roleNotAssigned: "Account setup pending"
        case .unauthorizedRole: "Access not authorized"
        case .accountDeletionFailed: "Account was not deleted"
        case .unknown: "Authentication failed"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .configurationMissing:
            "Add the Firebase Apple configuration and Authentication SDK before using account services."
        case .invalidCredentials:
            "The email or password was not accepted. Check your details and try again."
        case .emailAlreadyInUse:
            "An account already uses this email address. Sign in or reset its password."
        case .emailNotVerified:
            "Open the verification email we sent you, verify your address, then sign in."
        case .weakPassword:
            "Firebase rejected this password. Choose a stronger password and try again."
        case .networkUnavailable:
            "The authentication service could not be reached. Check your connection and try again."
        case .emailQuotaExceeded:
            "Firebase has reached its daily email sign-in quota. Try again after the quota resets, or use another configured sign-in method."
        case .biometricsUnavailable:
            "Set up Face ID or Touch ID in device Settings, then try again."
        case .biometricsNotConfigured:
            "Sign in with your password, then enable biometric sign-in from Profile → Face ID and security."
        case .biometricAuthenticationCancelled:
            "Face ID or Touch ID was cancelled. You can try again or use your password."
        case .biometricCredentialFailure:
            "The protected sign-in credential could not be read. Sign in with your password and enable biometrics again."
        case .invalidRegistrationLink:
            "This verification link is invalid or has expired. Request a new link and try again."
        case .emailLinkNotEnabled:
            "In Firebase Authentication, open Email/Password and enable Email link (passwordless sign-in), then save."
        case .invalidContinueURL:
            "Add fuelsmart-lk.firebaseapp.com to Firebase Authentication authorized domains."
        case .missingRegistrationEmail:
            "For security, request a new verification link on this device."
        case .roleNotAssigned:
            "Your account was created, but server-authorized workspace access has not been assigned yet."
        case .unauthorizedRole:
            "This account does not have an authorized FuelSmart LK role."
        case .accountDeletionFailed:
            "Your account remains active. Sign in again and retry, or contact support if the problem continues."
        case .unknown:
            "The authentication request could not be completed. Try again."
        }
    }
}

@MainActor
protocol AuthenticationService {
    func restoreAccount() async throws -> AuthenticatedAccount?
    func signIn(email: String, password: String) async throws -> AuthenticatedAccount
    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedAccount
    func registerCustomer(email: String, password: String) async throws -> AuthenticatedAccount
    func sendRegistrationLink(email: String) async throws
    func completeRegistrationLink(_ url: URL) async throws -> AuthenticatedAccount
    func updatePassword(_ password: String) async throws
    func sendPasswordReset(email: String) async throws
    func deleteCurrentAccount(password: String?) async throws
    func signOut() throws
}

extension AuthenticationService {
    func deleteCurrentAccount(password: String?) async throws {
        throw AuthenticationIssue.configurationMissing
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedAccount {
        throw AuthenticationIssue.configurationMissing
    }
}

@MainActor
struct FirebaseAuthenticationService: AuthenticationService {
    private static let pendingRegistrationEmailKey = "FuelLanka.pendingRegistrationEmail"

    func restoreAccount() async throws -> AuthenticatedAccount? {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable else {
            throw AuthenticationIssue.configurationMissing
        }
        guard let user = Auth.auth().currentUser else { return nil }
        guard user.isEmailVerified else {
            try? Auth.auth().signOut()
            return nil
        }
        return try await account(for: user, mayCreateCustomerRecord: false)
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedAccount {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable else {
            throw AuthenticationIssue.configurationMissing
        }
        do {
            let normalizedEmail = normalized(email)
            let result = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)
            guard result.user.isEmailVerified else {
                try? await result.user.sendEmailVerification()
                try? Auth.auth().signOut()
                throw AuthenticationIssue.emailNotVerified
            }
            return try await authorizedAccount(
                for: result.user,
                mayCreateCustomerRecord: false
            )
        } catch {
            throw map(error)
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedAccount {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable else {
            throw AuthenticationIssue.configurationMissing
        }
        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: fullName
            )
            let result = try await Auth.auth().signIn(with: credential)
            let account = try await authorizedAccount(
                for: result.user,
                mayCreateCustomerRecord: result.additionalUserInfo?.isNewUser == true
            )
            try await setPasswordConfigured(false, for: result.user)
            return AuthenticatedAccount(
                id: account.id,
                email: account.email,
                role: account.role,
                hasPassword: false
            )
        } catch {
            throw map(error)
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func registerCustomer(email: String, password: String) async throws -> AuthenticatedAccount {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable else {
            throw AuthenticationIssue.configurationMissing
        }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let account = try await authorizedAccount(for: result.user, mayCreateCustomerRecord: true)
            try await setPasswordConfigured(true, for: result.user)
            try await result.user.sendEmailVerification()
            try Auth.auth().signOut()
            return account
        } catch {
            throw map(error)
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func sendRegistrationLink(email: String) async throws {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable,
              let bundleIdentifier = Bundle.main.bundleIdentifier,
              let continuationURL = URL(string: "https://fuelsmart-lk.firebaseapp.com/finishSignUp") else {
            throw AuthenticationIssue.configurationMissing
        }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let settings = ActionCodeSettings()
        settings.url = continuationURL
        settings.handleCodeInApp = true
        settings.setIOSBundleID(bundleIdentifier)

        do {
            try await Auth.auth().sendSignInLink(toEmail: normalizedEmail, actionCodeSettings: settings)
            UserDefaults.standard.set(normalizedEmail, forKey: Self.pendingRegistrationEmailKey)
        } catch {
            throw map(error)
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func completeRegistrationLink(_ url: URL) async throws -> AuthenticatedAccount {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable else {
            throw AuthenticationIssue.configurationMissing
        }

        let link = url.absoluteString
        guard Auth.auth().isSignIn(withEmailLink: link) else {
            throw AuthenticationIssue.invalidRegistrationLink
        }
        guard let email = UserDefaults.standard.string(forKey: Self.pendingRegistrationEmailKey) else {
            throw AuthenticationIssue.missingRegistrationEmail
        }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, link: link)
            UserDefaults.standard.removeObject(forKey: Self.pendingRegistrationEmailKey)
            try await addDefaultDisplayNameIfNeeded(to: result.user, email: email)
            return try await authorizedAccount(
                for: result.user,
                mayCreateCustomerRecord: result.additionalUserInfo?.isNewUser == true
            )
        } catch let issue as AuthenticationIssue {
            throw issue
        } catch {
            throw map(error)
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func updatePassword(_ password: String) async throws {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable, let user = Auth.auth().currentUser else {
            throw AuthenticationIssue.configurationMissing
        }
        do {
            try await user.updatePassword(to: password)
            try await setPasswordConfigured(true, for: user)
        } catch {
            throw map(error)
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func sendPasswordReset(email: String) async throws {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable else {
            throw AuthenticationIssue.configurationMissing
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalized(email))
        } catch {
            throw map(error)
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func deleteCurrentAccount(password: String?) async throws {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable,
              let user = Auth.auth().currentUser else {
            throw AuthenticationIssue.configurationMissing
        }

        do {
            if user.providerData.contains(where: { $0.providerID == "password" }) {
                guard let email = user.email,
                      let password,
                      !password.isEmpty else {
                    throw AuthenticationIssue.invalidCredentials
                }
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                try await user.reauthenticate(with: credential)
            }

            let database = Firestore.firestore()
            let userReference = database.collection("users").document(user.uid)
            let profileSnapshot = try await userReference.getDocument()
            let profileData = profileSnapshot.data()

            for collectionName in ["notificationTokens", "notifications"] {
                let snapshot = try await userReference.collection(collectionName).getDocuments()
                for document in snapshot.documents {
                    try await document.reference.delete()
                }
            }
            try await userReference.delete()

            do {
                try await user.delete()
                BiometricCredentialStore().remove()
            } catch {
                if let profileData {
                    try? await userReference.setData(profileData)
                }
                throw error
            }
        } catch let issue as AuthenticationIssue {
            throw issue
        } catch {
            let mappedIssue = map(error)
            throw mappedIssue == .unknown ? AuthenticationIssue.accountDeletionFailed : mappedIssue
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    func signOut() throws {
        #if canImport(FirebaseAuth)
        guard FirebaseConfiguration.isAvailable else {
            throw AuthenticationIssue.configurationMissing
        }
        do {
            try Auth.auth().signOut()
        } catch {
            throw map(error)
        }
        #else
        throw AuthenticationIssue.configurationMissing
        #endif
    }

    #if canImport(FirebaseAuth)
    private func authorizedAccount(
        for user: User,
        mayCreateCustomerRecord: Bool
    ) async throws -> AuthenticatedAccount {
        do {
            return try await account(
                for: user,
                mayCreateCustomerRecord: mayCreateCustomerRecord
            )
        } catch {
            // Firebase can establish a local session before application-level
            // authorization fails. Remove it so rejected users cannot continue.
            try? Auth.auth().signOut()
            throw error
        }
    }

    private func account(
        for user: User,
        mayCreateCustomerRecord: Bool
    ) async throws -> AuthenticatedAccount {
        do {
            let token = try await user.getIDTokenResult(forcingRefresh: true)
            let role = try await assignedRole(
                for: user,
                tokenClaims: token.claims,
                mayCreateCustomerRecord: mayCreateCustomerRecord
            )

            if role == .customer, mayCreateCustomerRecord {
                try await ensureCustomerRecord(for: user)
            }

            let profile = try await Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .getDocument()
                .data()
            let hasPassword = profile?["passwordConfigured"] as? Bool
                ?? user.providerData.contains { $0.providerID == "password" }
            return AuthenticatedAccount(
                id: user.uid,
                email: user.email,
                role: role,
                hasPassword: hasPassword
            )
        } catch let issue as AuthenticationIssue {
            throw issue
        } catch {
            throw map(error)
        }
    }

    private func assignedRole(
        for user: User,
        tokenClaims: [String: Any],
        mayCreateCustomerRecord: Bool
    ) async throws -> AccountRole {
        let document = try await Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .getDocument()

        if let data = document.data() {
            guard let roleValue = data["role"] as? String else {
                throw AuthenticationIssue.roleNotAssigned
            }
            guard let role = AccountRole(rawValue: roleValue) else {
                throw AuthenticationIssue.unauthorizedRole
            }
            return role
        }

        if mayCreateCustomerRecord {
            return .customer
        }

        // Custom claims remain a secure fallback when privileged server
        // tooling assigns a role before creating the Firestore profile.
        if let roleValue = tokenClaims["role"] as? String {
            guard let role = AccountRole(rawValue: roleValue) else {
                throw AuthenticationIssue.unauthorizedRole
            }
            return role
        }

        throw AuthenticationIssue.roleNotAssigned
    }

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func setPasswordConfigured(_ isConfigured: Bool, for user: User) async throws {
        try await Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .setData(["passwordConfigured": isConfigured], merge: true)
    }

    private func ensureCustomerRecord(for user: User) async throws {
        let reference = Firestore.firestore().collection("users").document(user.uid)
        let document = try await reference.getDocument()
        guard !document.exists else { return }

        var data: [String: Any] = [
            "role": AccountRole.customer.rawValue,
            "preferredFuels": [String](),
            "restockAlerts": false,
            "priceAlerts": false,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let email = user.email {
            data["email"] = email
        }
        if let displayName = user.displayName, !displayName.isEmpty {
            data["fullName"] = displayName
        }
        try await reference.setData(data)
    }

    private func addDefaultDisplayNameIfNeeded(to user: User, email: String) async throws {
        guard user.displayName?.isEmpty != false else { return }
        let emailName = email.split(separator: "@", maxSplits: 1).first.map(String.init) ?? "Customer"
        let words = emailName
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let displayName = words.capitalized.trimmingCharacters(in: .whitespacesAndNewlines)

        let request = user.createProfileChangeRequest()
        request.displayName = displayName.isEmpty ? "Customer" : displayName
        try await request.commitChanges()
    }

    private func map(_ error: Error) -> AuthenticationIssue {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .invalidCredential, .wrongPassword, .userNotFound, .invalidEmail:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkUnavailable
        case .quotaExceeded:
            return .emailQuotaExceeded
        case .invalidActionCode, .expiredActionCode:
            return .invalidRegistrationLink
        case .operationNotAllowed:
            return .emailLinkNotEnabled
        case .invalidContinueURI, .missingContinueURI, .unauthorizedDomain:
            return .invalidContinueURL
        default:
            let error = error as NSError
            print("Firebase Auth error [\(error.domain):\(error.code)]: \(error.localizedDescription)")
            return .unknown
        }
    }
    #endif
}

enum AuthenticationStatus: Equatable {
    case checking
    case signedOut
    case passwordSetup(AuthenticatedAccount)
    case authenticated(AuthenticatedAccount)
    case blocked(AuthenticationIssue)
}

@MainActor
@Observable
final class AuthenticationSession {
    private let service: any AuthenticationService

    private(set) var status: AuthenticationStatus = .checking
    private(set) var isSubmitting = false
    private(set) var issue: AuthenticationIssue?

    var currentAccount: AuthenticatedAccount? {
        switch status {
        case .passwordSetup(let account), .authenticated(let account): account
        default: nil
        }
    }

    init() {
        service = FirebaseAuthenticationService()
    }

    init(service: any AuthenticationService) {
        self.service = service
    }

    func restore() async {
        do {
            if let account = try await service.restoreAccount() {
                status = account.hasPassword ? .authenticated(account) : .passwordSetup(account)
            } else {
                status = .signedOut
            }
        } catch let issue as AuthenticationIssue {
            status = issue == .configurationMissing ? .signedOut : .blocked(issue)
            self.issue = issue
        } catch {
            status = .signedOut
            issue = .unknown
        }
    }

    func signIn(email: String, password: String) async {
        await perform {
            let account = try await service.signIn(email: email, password: password)
            transition(to: account)
        }
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async -> Bool {
        var succeeded = false
        await perform {
            let account = try await service.signInWithApple(
                idToken: idToken,
                rawNonce: rawNonce,
                fullName: fullName
            )
            transition(to: account)
            succeeded = true
        }
        return succeeded
    }

    func registerCustomer(email: String, password: String) async -> Bool {
        var succeeded = false
        await perform {
            let account = try await service.registerCustomer(email: email, password: password)
            _ = account
            status = .signedOut
            succeeded = true
        }
        return succeeded
    }

    func sendRegistrationLink(email: String) async -> Bool {
        var succeeded = false
        await perform {
            try await service.sendRegistrationLink(email: email)
            succeeded = true
        }
        return succeeded
    }

    func handleIncomingURL(_ url: URL) async {
        await perform {
            let account = try await service.completeRegistrationLink(url)
            status = account.hasPassword ? .authenticated(account) : .passwordSetup(account)
        }
    }

    func completePasswordSetup(password: String) async -> Bool {
        guard case .passwordSetup(let account) = status else {
            issue = .invalidCredentials
            return false
        }

        var succeeded = false
        await perform {
            try await service.updatePassword(password)
            status = .authenticated(
                AuthenticatedAccount(
                    id: account.id,
                    email: account.email,
                    role: account.role,
                    hasPassword: true
                )
            )
            succeeded = true
        }
        return succeeded
    }

    func enableBiometricSignIn(password: String) async -> Bool {
        guard case .authenticated(let account) = status, let email = account.email else {
            issue = .invalidCredentials
            return false
        }

        let credentialStore = BiometricCredentialStore()
        guard credentialStore.biometricType != .unavailable else {
            issue = .biometricsUnavailable
            return false
        }

        var succeeded = false
        await perform {
            do {
                _ = try await service.signIn(email: email, password: password)
                try credentialStore.save(email: email, password: password)
                succeeded = true
            } catch {
                throw mapBiometricError(error)
            }
        }
        return succeeded
    }

    func signInWithBiometrics() async -> Bool {
        var succeeded = false
        await perform {
            do {
                let credential = try await BiometricCredentialStore().credential(
                    reason: String(localized: "Sign in to FuelSmart LK")
                )
                let account = try await service.signIn(
                    email: credential.email,
                    password: credential.password
                )
                status = .authenticated(account)
                succeeded = true
            } catch let issue as AuthenticationIssue {
                throw issue
            } catch {
                throw mapBiometricError(error)
            }
        }
        return succeeded
    }

    private func mapBiometricError(_ error: Error) -> AuthenticationIssue {
        guard let biometricError = error as? BiometricCredentialError else {
            return .biometricCredentialFailure
        }

        switch biometricError {
        case .unavailable: return .biometricsUnavailable
        case .cancelled: return .biometricAuthenticationCancelled
        case .notConfigured: return .biometricsNotConfigured
        case .keychainFailure: return .biometricCredentialFailure
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        var succeeded = false
        await perform {
            try await service.sendPasswordReset(email: email)
            succeeded = true
        }
        return succeeded
    }

    func deleteAccount(password: String?) async -> Bool {
        var succeeded = false
        await perform {
            try await service.deleteCurrentAccount(password: password)
            BiometricCredentialStore().remove()
            status = .signedOut
            succeeded = true
        }
        return succeeded
    }

    func signOut() {
        let userID = currentAccount?.id
        Task {
            await NotificationService.shared.removeCurrentToken(userID: userID)
            do {
                try service.signOut()
                status = .signedOut
                issue = nil
            } catch let authIssue as AuthenticationIssue {
                issue = authIssue
            } catch {
                issue = .unknown
            }
        }
    }

    func clearIssue() {
        issue = nil
    }

    private func transition(to account: AuthenticatedAccount) {
        status = account.hasPassword ? .authenticated(account) : .passwordSetup(account)
    }

    private func perform(_ operation: () async throws -> Void) async {
        isSubmitting = true
        issue = nil
        defer { isSubmitting = false }

        do {
            try await operation()
        } catch let authIssue as AuthenticationIssue {
            issue = authIssue
            if authIssue == .roleNotAssigned || authIssue == .unauthorizedRole {
                status = .blocked(authIssue)
            }
        } catch {
            issue = .unknown
        }
    }
}

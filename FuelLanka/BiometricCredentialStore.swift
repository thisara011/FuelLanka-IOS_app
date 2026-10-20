import Foundation
import LocalAuthentication
import Security

enum BiometricType: Equatable, Sendable {
    case faceID
    case touchID
    case unavailable

    var title: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .unavailable: "Biometric sign-in"
        }
    }

    var systemImage: String {
        switch self {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .unavailable: "lock.shield"
        }
    }
}

struct BiometricCredential: Codable, Equatable, Sendable {
    let email: String
    let password: String
}

enum BiometricCredentialError: Error, Equatable {
    case unavailable
    case cancelled
    case notConfigured
    case keychainFailure
}

struct BiometricCredentialStore {
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable
        }

        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .unavailable
        }
    }

    private let service = "lk.fuelsmart.authentication"
    private let account = "firebase-password"

    func save(email: String, password: String) throws {
        guard let data = try? JSONEncoder().encode(
            BiometricCredential(email: email, password: password)
        ) else {
            throw BiometricCredentialError.keychainFailure
        }

        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &accessControlError
        ) else {
            throw BiometricCredentialError.unavailable
        }

        SecItemDelete(baseQuery as CFDictionary)

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessControl as String] = accessControl

        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw BiometricCredentialError.keychainFailure
        }
    }

    func credential(reason: String) async throws -> BiometricCredential {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Use password")

        var evaluationError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evaluationError) else {
            throw BiometricCredentialError.unavailable
        }

        do {
            guard try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) else {
                throw BiometricCredentialError.cancelled
            }
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel || error.code == .systemCancel {
            throw BiometricCredentialError.cancelled
        } catch {
            throw BiometricCredentialError.unavailable
        }

        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else {
            throw BiometricCredentialError.notConfigured
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let credential = try? JSONDecoder().decode(BiometricCredential.self, from: data) else {
            throw BiometricCredentialError.keychainFailure
        }
        return credential
    }

    func remove() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

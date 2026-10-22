import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct FederatedSignInSection: View {
    let authentication: AuthenticationSession
    let onFailure: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Rectangle()
                    .frame(height: 1)
                Text("or")
                    .font(.footnote)
                Rectangle()
                    .frame(height: 1)
            }
            .foregroundStyle(.secondary.opacity(0.4))

            AppleAuthenticationButton(
                authentication: authentication,
                onFailure: onFailure
            )
        }
    }
}

struct AppleAuthenticationButton: View {
    let authentication: AuthenticationSession
    let onFailure: () -> Void

    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = AppleSignInNonce.random()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                complete(authorization)
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code != .canceled {
                    onFailure()
                }
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity, minHeight: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("authentication.apple")
        .disabled(authentication.isSubmitting)
    }

    private func complete(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let currentNonce,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            onFailure()
            return
        }

        Task {
            let succeeded = await authentication.signInWithApple(
                idToken: idToken,
                rawNonce: currentNonce,
                fullName: credential.fullName
            )
            if !succeeded {
                onFailure()
            }
        }
    }
}

enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == errSecSuccess else {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }

            for byte in randomBytes where remaining > 0 {
                if byte < characters.count {
                    result.append(characters[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

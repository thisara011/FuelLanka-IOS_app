import Testing
@testable import FuelLanka

struct AppleSignInNonceTests {
    @Test func createsRequestedNonceLength() {
        let nonce = AppleSignInNonce.random(length: 32)

        #expect(nonce.count == 32)
    }

    @Test func hashesNonceWithSHA256() {
        let hash = AppleSignInNonce.sha256("FuelSmart LK")

        #expect(hash == "3d2675b1a8f22a2ada02f8e4e0417cef22e1da477cd5567806990af7d56d0593")
    }
}

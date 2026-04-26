import Foundation
import Security

final class CryptoService {
    static let shared = CryptoService()
    private init() {}

    func generateKeypair() -> (publicKey: String, privateKey: String) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256
        ]
        guard
            let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, nil),
            let publicKey = SecKeyCopyPublicKey(privateKey),
            let privateData = SecKeyCopyExternalRepresentation(privateKey, nil) as Data?,
            let publicData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
        else {
            return (UUID().uuidString, UUID().uuidString)
        }
        return (
            publicKey: publicData.base64EncodedString(),
            privateKey: privateData.base64EncodedString()
        )
    }
}

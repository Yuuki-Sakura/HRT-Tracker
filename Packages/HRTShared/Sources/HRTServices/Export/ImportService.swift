import Foundation
import HRTModels
import CryptoKit

public struct ImportService: Sendable {
    public init() {}

    public func importJSON(data: Data) throws -> ExportBundle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportBundle.self, from: data)
    }

    public func importEncryptedJSON(data: Data, password: String) throws -> ExportBundle {
        let encrypted = try JSONDecoder().decode(EncryptedBundle.self, from: data)
        guard encrypted.encrypted else {
            return try importJSON(data: data)
        }

        guard let saltData = Data(base64Encoded: encrypted.salt),
              let ivData = Data(base64Encoded: encrypted.iv) else {
            throw ImportError.invalidFormat
        }

        let components = encrypted.data.split(separator: ":")
        guard components.count == 2,
              let ciphertext = Data(base64Encoded: String(components[0])),
              let tag = Data(base64Encoded: String(components[1])) else {
            throw ImportError.invalidFormat
        }

        let iterations = encrypted.iter > 0 ? encrypted.iter : 100_000
        let key = deriveKey(password: password, salt: Array(saltData), iterations: iterations)
        let nonce = try AES.GCM.Nonce(data: ivData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return try importJSON(data: decryptedData)
    }

    private func deriveKey(password: String, salt: [UInt8], iterations: Int) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let saltData = Data(salt)
        var derivedKey = Data(count: 32)

        _ = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                saltData.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        return SymmetricKey(data: derivedKey)
    }
}

public enum ImportError: Error, LocalizedError {
    case invalidFormat
    case decryptionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid file format"
        case .decryptionFailed: return "Decryption failed - wrong password?"
        }
    }
}

#if canImport(CommonCrypto)
import CommonCrypto
#endif

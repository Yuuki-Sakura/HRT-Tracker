import Foundation
import HRTModels
import CryptoKit

public struct ExportBundle: Codable, Sendable {
    public let version: Int
    public let exportDate: Date
    public let events: [DoseEvent]
    public let labResults: [LabResult]

    public init(events: [DoseEvent], labResults: [LabResult]) {
        self.version = 1
        self.exportDate = Date()
        self.events = events
        self.labResults = labResults
    }
}

public struct EncryptedBundle: Codable, Sendable {
    public let encrypted: Bool
    public let iv: String
    public let salt: String
    public let iter: Int
    public let data: String
}

public struct ExportService: Sendable {
    public init() {}

    public func exportJSON(events: [DoseEvent], labResults: [LabResult]) throws -> Data {
        let bundle = ExportBundle(events: events, labResults: labResults)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }

    public func exportCSV(events: [DoseEvent]) -> String {
        var csv = "id,route,timestamp,date,doseMG,ester,extras\n"
        let dateFormatter = ISO8601DateFormatter()

        for event in events {
            let extrasStr: String
            if event.extras.isEmpty {
                extrasStr = ""
            } else {
                let pairs = event.extras.map { "\($0.key.rawValue)=\($0.value)" }
                extrasStr = "\"\(pairs.joined(separator: ";"))\""
            }
            let dateStr = dateFormatter.string(from: event.date)
            csv += "\(event.id),\(event.route.rawValue),\(event.timestamp),\(dateStr),\(event.doseMG),\(event.ester.rawValue),\(extrasStr)\n"
        }

        return csv
    }

    public func exportEncryptedJSON(events: [DoseEvent], labResults: [LabResult], password: String) throws -> Data {
        let plainData = try exportJSON(events: events, labResults: labResults)

        let salt = generateRandomBytes(count: 16)
        let iv = generateRandomBytes(count: 12)
        let iterations = 600_000

        let key = deriveKey(password: password, salt: salt, iterations: iterations)
        let sealedBox = try AES.GCM.seal(plainData, using: key, nonce: AES.GCM.Nonce(data: iv))

        let bundle = EncryptedBundle(
            encrypted: true,
            iv: Data(iv).base64EncodedString(),
            salt: Data(salt).base64EncodedString(),
            iter: iterations,
            data: sealedBox.ciphertext.base64EncodedString() + ":" + sealedBox.tag.base64EncodedString()
        )

        return try JSONEncoder().encode(bundle)
    }

    private func generateRandomBytes(count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return bytes
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

#if canImport(CommonCrypto)
import CommonCrypto
#endif

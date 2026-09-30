import CryptoKit
import Foundation

public struct SigV4: Sendable {
    public let accessKeyId: String
    public let secretAccessKey: String
    public let region: String
    public let service: String

    public init(accessKeyId: String, secretAccessKey: String, region: String, service: String) {
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.region = region
        self.service = service
    }

    public func authorization(
        method: String,
        path: String,
        query: [String: String],
        headers: [String: String],
        payloadHash: String,
        timestamp: String
    ) -> String {
        let day = String(timestamp.prefix(8))
        let scopeParts = [day, region, service, "aws4_request"]
        let scope = scopeParts.joined(separator: "/")
        let signed = headers
            .map { (name: $0.key.lowercased(), value: SigV4.clean($0.value)) }
            .sorted { $0.name < $1.name }
        let signedNames = signed.map(\.name).joined(separator: ";")
        let canonical = [
            method,
            SigV4.encode(path, keepSlash: true),
            SigV4.canonicalQuery(query),
            signed.map { "\($0.name):\($0.value)\n" }.joined(),
            signedNames,
            payloadHash
        ].joined(separator: "\n")
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            timestamp,
            scope,
            SigV4.sha256Hex(Data(canonical.utf8))
        ].joined(separator: "\n")
        var key = Data("AWS4\(secretAccessKey)".utf8)
        for part in scopeParts {
            key = SigV4.hmac(key: key, message: part)
        }
        let signature = SigV4.hex(SigV4.hmac(key: key, message: stringToSign))
        return "AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(scope), SignedHeaders=\(signedNames), Signature=\(signature)"
    }

    public static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    public static func sha256Hex(_ data: Data) -> String {
        hex(Data(SHA256.hash(data: data)))
    }

    public static func encode(_ text: String, keepSlash: Bool) -> String {
        var result = ""
        for byte in text.utf8 {
            let scalar = Unicode.Scalar(byte)
            let character = Character(scalar)
            let unreserved = byte < 128 && (character.isLetter || character.isNumber || "-._~".contains(character))
            if unreserved || (keepSlash && character == "/") {
                result.append(character)
            } else {
                result += String(format: "%%%02X", byte)
            }
        }
        return result
    }

    public static func canonicalQuery(_ query: [String: String]) -> String {
        query
            .map { (name: encode($0.key, keepSlash: false), value: encode($0.value, keepSlash: false)) }
            .sorted { $0.name < $1.name }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "&")
    }

    static func clean(_ value: String) -> String {
        value.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    static func hmac(key: Data, message: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: key)))
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

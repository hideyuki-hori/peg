import Foundation

public enum UUIDv7 {
    public static func make(at date: Date = Date()) -> String {
        var generator = SystemRandomNumberGenerator()
        let random = (0..<10).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return make(milliseconds: UInt64(max(date.timeIntervalSince1970, 0) * 1000), random: random)
    }

    public static func make(milliseconds: UInt64, random: [UInt8]) -> String {
        var bytes = (0..<6).map { UInt8(truncatingIfNeeded: milliseconds >> UInt64(8 * (5 - $0))) }
        bytes += (0..<10).map { $0 < random.count ? random[$0] : 0 }
        bytes[6] = (bytes[6] & 0x0F) | 0x70
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }
        let groups = [hex[0..<4], hex[4..<6], hex[6..<8], hex[8..<10], hex[10..<16]]
        return groups.map { $0.joined() }.joined(separator: "-")
    }
}

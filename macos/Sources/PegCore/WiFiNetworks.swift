import Foundation

public struct WiFiNetwork: Identifiable, Hashable, Sendable {
    public let ssid: String
    public let rssi: Int
    public let isSecure: Bool

    public init(ssid: String, rssi: Int, isSecure: Bool) {
        self.ssid = ssid
        self.rssi = rssi
        self.isSecure = isSecure
    }

    public var id: String {
        ssid
    }

    public var strength: Double {
        WiFiNetworks.strength(rssi: rssi)
    }
}

public enum WiFiNetworks {
    public static func parsePreferred(_ text: String) -> [String] {
        var names: [String] = []
        var seen = Set<String>()
        for line in text.components(separatedBy: .newlines).dropFirst() {
            guard let first = line.first, first == "\t" || first == " " else { continue }
            let name = line.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            names.append(name)
        }
        return names
    }

    public static func knownNearby(scanned: [WiFiNetwork], preferred: [String], current: String?) -> [WiFiNetwork] {
        let known = Set(preferred)
        var strongest: [String: WiFiNetwork] = [:]
        for network in scanned {
            guard known.contains(network.ssid), network.ssid != current else { continue }
            if let existing = strongest[network.ssid], existing.rssi >= network.rssi {
                continue
            }
            strongest[network.ssid] = network
        }
        return strongest.values.sorted { left, right in
            if left.rssi != right.rssi {
                return left.rssi > right.rssi
            }
            return left.ssid < right.ssid
        }
    }

    public static func strength(rssi: Int) -> Double {
        if rssi >= -55 {
            return 1
        }
        if rssi >= -67 {
            return 0.66
        }
        if rssi >= -80 {
            return 0.33
        }
        return 0.1
    }
}

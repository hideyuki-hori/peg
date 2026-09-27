import Foundation

public enum ChargeLevel: Sendable {
    case low
    case medium
    case high

    public init(percent: Int) {
        if percent <= 20 {
            self = .low
        } else if percent <= 40 {
            self = .medium
        } else {
            self = .high
        }
    }
}

public struct BatteryReport: Equatable, Sendable {
    public enum State: Sendable {
        case charging
        case full
        case pluggedIn
        case onBattery
    }

    public let percent: Int
    public let state: State
    public let minutesRemaining: Int?
    public let adapterWatts: Int?
    public let healthPercent: Int?

    public init(percent: Int, state: State, minutesRemaining: Int?, adapterWatts: Int?, healthPercent: Int?) {
        self.percent = percent
        self.state = state
        self.minutesRemaining = minutesRemaining
        self.adapterWatts = adapterWatts
        self.healthPercent = healthPercent
    }

    public var level: ChargeLevel {
        ChargeLevel(percent: percent)
    }

    public var stateText: String {
        switch state {
        case .charging:
            return "充電中"
        case .full:
            return "充電済み"
        case .pluggedIn:
            return "電源に接続"
        case .onBattery:
            return "バッテリー駆動"
        }
    }

    public var remainingText: String {
        switch state {
        case .full:
            return "フル充電"
        case .charging:
            guard let minutesRemaining else { return "充電時間を計算中" }
            return "フル充電まで " + ClockFormat.duration(minutes: minutesRemaining)
        case .pluggedIn:
            return "充電を保留中"
        case .onBattery:
            guard let minutesRemaining else { return "残り時間を計算中" }
            return "残り " + ClockFormat.duration(minutes: minutesRemaining)
        }
    }

    public var sourceText: String {
        switch state {
        case .onBattery:
            return "バッテリー"
        case .charging, .full, .pluggedIn:
            guard let adapterWatts, adapterWatts > 0 else { return "電源アダプタ" }
            return "電源アダプタ \(adapterWatts)W"
        }
    }

    public static func parse(ioreg data: Data) -> BatteryReport? {
        guard let entry = (try? PropertyListDecoder().decode([Entry].self, from: data))?.first else { return nil }
        guard let current = entry.currentCapacity, let maximum = entry.maxCapacity, maximum > 0 else { return nil }
        let percent = min(max(Int((Double(current) / Double(maximum) * 100).rounded()), 0), 100)
        let plugged = entry.externalConnected ?? false
        let charging = entry.isCharging ?? false
        let full = entry.fullyCharged ?? false
        let state: State
        if !plugged {
            state = .onBattery
        } else if charging {
            state = .charging
        } else if full || percent >= 100 {
            state = .full
        } else {
            state = .pluggedIn
        }
        let minutes = state == .charging ? entry.avgTimeToFull : entry.avgTimeToEmpty
        var health: Int?
        if let nominal = entry.nominalChargeCapacity, let design = entry.designCapacity, design > 0 {
            health = min(Int((Double(nominal) / Double(design) * 100).rounded()), 100)
        }
        return BatteryReport(
            percent: percent,
            state: state,
            minutesRemaining: valid(minutes),
            adapterWatts: entry.adapterDetails?.watts,
            healthPercent: health
        )
    }

    static func valid(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0, minutes < 65535 else { return nil }
        return minutes
    }

    struct Entry: Decodable {
        let currentCapacity: Int?
        let maxCapacity: Int?
        let isCharging: Bool?
        let externalConnected: Bool?
        let fullyCharged: Bool?
        let avgTimeToFull: Int?
        let avgTimeToEmpty: Int?
        let nominalChargeCapacity: Int?
        let designCapacity: Int?
        let adapterDetails: Adapter?

        enum CodingKeys: String, CodingKey {
            case currentCapacity = "CurrentCapacity"
            case maxCapacity = "MaxCapacity"
            case isCharging = "IsCharging"
            case externalConnected = "ExternalConnected"
            case fullyCharged = "FullyCharged"
            case avgTimeToFull = "AvgTimeToFull"
            case avgTimeToEmpty = "AvgTimeToEmpty"
            case nominalChargeCapacity = "NominalChargeCapacity"
            case designCapacity = "DesignCapacity"
            case adapterDetails = "AdapterDetails"
        }
    }

    struct Adapter: Decodable {
        let watts: Int?

        enum CodingKeys: String, CodingKey {
            case watts = "Watts"
        }
    }
}

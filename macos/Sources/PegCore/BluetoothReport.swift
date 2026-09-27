import Foundation

public struct BluetoothDevice: Identifiable, Hashable, Sendable {
    public enum Kind: Sendable {
        case headphones
        case speaker
        case keyboard
        case mouse
        case trackpad
        case gamepad
        case phone
        case computer
        case display
        case other
    }

    public let address: String
    public let name: String
    public let kind: Kind
    public let isConnected: Bool
    public let battery: Int?
    public let left: Int?
    public let right: Int?
    public let chargingCase: Int?

    public init(
        address: String,
        name: String,
        kind: Kind,
        isConnected: Bool,
        battery: Int? = nil,
        left: Int? = nil,
        right: Int? = nil,
        chargingCase: Int? = nil
    ) {
        self.address = address
        self.name = name
        self.kind = kind
        self.isConnected = isConnected
        self.battery = battery
        self.left = left
        self.right = right
        self.chargingCase = chargingCase
    }

    public var id: String {
        address
    }

    public var summaryBattery: Int? {
        if let battery {
            return battery
        }
        let parts = [left, right].compactMap { $0 }
        return parts.min()
    }

    public var hasParts: Bool {
        left != nil || right != nil || chargingCase != nil
    }
}

public struct BluetoothReport: Equatable, Sendable {
    public let isPoweredOn: Bool
    public let devices: [BluetoothDevice]

    public init(isPoweredOn: Bool, devices: [BluetoothDevice]) {
        self.isPoweredOn = isPoweredOn
        self.devices = devices
    }

    public var connected: [BluetoothDevice] {
        devices.filter(\.isConnected)
    }

    public var disconnected: [BluetoothDevice] {
        devices.filter { !$0.isConnected }
    }

    public static func parse(systemProfiler data: Data, hidBatteries: Data? = nil) -> BluetoothReport? {
        guard let root = (try? JSONDecoder().decode(Root.self, from: data))?.items.first else { return nil }
        let batteries = hidLevels(from: hidBatteries)
        var devices: [BluetoothDevice] = []
        var seen = Set<String>()
        let groups: [(items: [[String: Properties]]?, connected: Bool)] = [
            (root.connected, true),
            (root.notConnected, false)
        ]
        for group in groups {
            for item in group.items ?? [] {
                for name in item.keys.sorted() {
                    guard let properties = item[name], let raw = properties.address else { continue }
                    let address = normalize(raw)
                    guard normalize(name) != address, properties.minorType != nil || group.connected else { continue }
                    guard seen.insert(address).inserted else { continue }
                    devices.append(BluetoothDevice(
                        address: address,
                        name: name,
                        kind: kind(for: properties.minorType),
                        isConnected: group.connected,
                        battery: percent(properties.batteryMain) ?? batteries[address],
                        left: percent(properties.batteryLeft),
                        right: percent(properties.batteryRight),
                        chargingCase: percent(properties.batteryCase)
                    ))
                }
            }
        }
        return BluetoothReport(isPoweredOn: root.controller?.state == "attrib_on", devices: devices)
    }

    static func hidLevels(from data: Data?) -> [String: Int] {
        guard let data, let entries = try? PropertyListDecoder().decode([HIDEntry].self, from: data) else { return [:] }
        var levels: [String: Int] = [:]
        for entry in entries {
            guard let address = entry.address, let percent = entry.percent else { continue }
            levels[normalize(address)] = percent
        }
        return levels
    }

    static func normalize(_ address: String) -> String {
        address.lowercased().replacingOccurrences(of: ":", with: "-")
    }

    static func percent(_ text: String?) -> Int? {
        guard let text else { return nil }
        let digits = text.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber }
        guard let value = Int(digits) else { return nil }
        return min(max(value, 0), 100)
    }

    static func kind(for minorType: String?) -> BluetoothDevice.Kind {
        guard let value = minorType?.lowercased() else { return .other }
        if value.contains("headphone") || value.contains("headset") {
            return .headphones
        }
        if value.contains("speaker") {
            return .speaker
        }
        if value.contains("keyboard") {
            return .keyboard
        }
        if value.contains("trackpad") {
            return .trackpad
        }
        if value.contains("mouse") {
            return .mouse
        }
        if value.contains("gamepad") || value.contains("game") || value.contains("joystick") {
            return .gamepad
        }
        if value.contains("phone") {
            return .phone
        }
        if value.contains("display") {
            return .display
        }
        if value.contains("computer") || value.contains("laptop") || value.contains("desktop") {
            return .computer
        }
        return .other
    }

    struct Root: Decodable {
        let items: [Section]

        enum CodingKeys: String, CodingKey {
            case items = "SPBluetoothDataType"
        }
    }

    struct Section: Decodable {
        let controller: Controller?
        let connected: [[String: Properties]]?
        let notConnected: [[String: Properties]]?

        enum CodingKeys: String, CodingKey {
            case controller = "controller_properties"
            case connected = "device_connected"
            case notConnected = "device_not_connected"
        }
    }

    struct Controller: Decodable {
        let state: String?

        enum CodingKeys: String, CodingKey {
            case state = "controller_state"
        }
    }

    struct Properties: Decodable {
        let address: String?
        let minorType: String?
        let batteryMain: String?
        let batteryLeft: String?
        let batteryRight: String?
        let batteryCase: String?

        enum CodingKeys: String, CodingKey {
            case address = "device_address"
            case minorType = "device_minorType"
            case batteryMain = "device_batteryLevelMain"
            case batteryLeft = "device_batteryLevelLeft"
            case batteryRight = "device_batteryLevelRight"
            case batteryCase = "device_batteryLevelCase"
        }
    }

    struct HIDEntry: Decodable {
        let address: String?
        let percent: Int?

        enum CodingKeys: String, CodingKey {
            case address = "DeviceAddress"
            case percent = "BatteryPercent"
        }
    }
}

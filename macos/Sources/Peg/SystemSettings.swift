import AppKit

enum SystemSettings {
    case wifi
    case bluetooth
    case battery
    case calendarPrivacy
    case locationPrivacy

    var address: String {
        switch self {
        case .wifi:
            return "x-apple.systempreferences:com.apple.wifi-settings-extension"
        case .bluetooth:
            return "x-apple.systempreferences:com.apple.BluetoothSettings"
        case .battery:
            return "x-apple.systempreferences:com.apple.Battery-Settings.extension"
        case .calendarPrivacy:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        case .locationPrivacy:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        }
    }

    func open() {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }
}

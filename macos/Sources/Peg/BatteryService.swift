import Foundation
import PegCore

enum BatteryService {
    static func load() -> BatteryReport? {
        guard let data = Shell.run("/usr/sbin/ioreg", ["-r", "-n", "AppleSmartBattery", "-a"]) else { return nil }
        return BatteryReport.parse(ioreg: data)
    }
}

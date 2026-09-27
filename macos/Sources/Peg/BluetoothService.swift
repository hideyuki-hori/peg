import Foundation
import IOBluetooth
import PegCore

@_silgen_name("IOBluetoothPreferenceSetControllerPowerState")
private func setControllerPowerState(_ state: Int32)

enum BluetoothService {
    static func load() -> BluetoothReport? {
        guard let profile = Shell.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"]) else { return nil }
        let batteries = Shell.run("/usr/sbin/ioreg", ["-r", "-k", "BatteryPercent", "-a"])
        return BluetoothReport.parse(systemProfiler: profile, hidBatteries: batteries)
    }

    static func setPower(_ isOn: Bool) {
        setControllerPowerState(isOn ? 1 : 0)
    }

    static func connect(_ address: String) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else { return false }
        return device.openConnection() == kIOReturnSuccess
    }

    static func disconnect(_ address: String) -> Bool {
        guard let device = IOBluetoothDevice(addressString: address) else { return false }
        return device.closeConnection() == kIOReturnSuccess
    }
}

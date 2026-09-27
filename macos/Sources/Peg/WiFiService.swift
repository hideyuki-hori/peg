import CoreWLAN
import Foundation
import PegCore

struct WiFiState: Equatable {
    var isAvailable = false
    var isPoweredOn = false
    var isConnected = false
    var ssid: String?
    var rssi = 0
    var isSecure = false
    var known: [WiFiNetwork] = []

    var strength: Double {
        WiFiNetworks.strength(rssi: rssi)
    }
}

final class WiFiService: @unchecked Sendable {
    private let client = CWWiFiClient()
    private let lock = NSLock()
    private var networks: [String: CWNetwork] = [:]
    private var known: [WiFiNetwork] = []

    func load(scan: Bool) -> WiFiState {
        guard let interface = client.interface() else { return WiFiState() }
        var state = WiFiState()
        state.isAvailable = true
        state.isPoweredOn = interface.powerOn()
        guard state.isPoweredOn else {
            store(networks: [:], known: [])
            return state
        }
        state.ssid = interface.ssid()
        state.rssi = interface.rssiValue()
        state.isConnected = state.ssid != nil || state.rssi != 0
        state.isSecure = interface.security() != .none
        if scan {
            rescan(interface, current: state.ssid)
        }
        state.known = cachedKnown().filter { $0.ssid != state.ssid }
        return state
    }

    func setPower(_ isOn: Bool) -> Bool {
        guard let interface = client.interface() else { return false }
        do {
            try interface.setPower(isOn)
            return true
        } catch {
            NSLog("Peg: failed to change Wi-Fi power: %@", error.localizedDescription)
            return false
        }
    }

    func join(_ ssid: String) -> Bool {
        guard let interface = client.interface(), let network = cachedNetwork(ssid) else { return false }
        do {
            try interface.associate(to: network, password: nil)
            return true
        } catch {
            NSLog("Peg: failed to join Wi-Fi network: %@", error.localizedDescription)
            return false
        }
    }

    private func rescan(_ interface: CWInterface, current: String?) {
        guard let found = try? interface.scanForNetworks(withSSID: nil) else { return }
        var scanned: [WiFiNetwork] = []
        var lookup: [String: CWNetwork] = [:]
        for network in found {
            guard let ssid = network.ssid, !ssid.isEmpty else { continue }
            scanned.append(WiFiNetwork(ssid: ssid, rssi: network.rssiValue, isSecure: !network.supportsSecurity(.none)))
            if let existing = lookup[ssid], existing.rssiValue >= network.rssiValue {
                continue
            }
            lookup[ssid] = network
        }
        let preferred = preferredNetworks(on: interface.interfaceName)
        store(networks: lookup, known: WiFiNetworks.knownNearby(scanned: scanned, preferred: preferred, current: current))
    }

    private func preferredNetworks(on name: String?) -> [String] {
        guard
            let name,
            let data = Shell.run("/usr/sbin/networksetup", ["-listpreferredwirelessnetworks", name]),
            let text = String(data: data, encoding: .utf8)
        else { return [] }
        return WiFiNetworks.parsePreferred(text)
    }

    private func store(networks: [String: CWNetwork], known: [WiFiNetwork]) {
        lock.lock()
        self.networks = networks
        self.known = known
        lock.unlock()
    }

    private func cachedKnown() -> [WiFiNetwork] {
        lock.lock()
        defer { lock.unlock() }
        return known
    }

    private func cachedNetwork(_ ssid: String) -> CWNetwork? {
        lock.lock()
        defer { lock.unlock() }
        return networks[ssid]
    }
}

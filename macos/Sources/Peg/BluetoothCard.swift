import PegCore
import SwiftUI

struct BluetoothCard: View {
    @ObservedObject var model: ControlPanelModel

    var body: some View {
        PanelCard(spacing: 8) {
            CardHeader(title: "Bluetooth") {
                BluetoothIcon()
            } trailing: {
                if let report = model.bluetooth {
                    PanelToggle(isOn: report.isPoweredOn, label: "Bluetooth", action: model.setBluetoothPower)
                }
            }
            content
            if let message = model.bluetoothMessage {
                MessageText(text: message)
            }
            PanelDivider()
            LinkRow(symbol: "gearshape", title: "Bluetooth 設定を開く") {
                model.open(.bluetooth)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let report = model.bluetooth {
            if !report.isPoweredOn {
                status("Bluetooth はオフです")
            } else {
                SectionLabel(text: "接続中のデバイス")
                if report.connected.isEmpty {
                    status("接続中のデバイスはありません")
                }
                ForEach(report.connected) { device in
                    ConnectedDeviceRow(
                        device: device,
                        isBusy: model.busyDevices.contains(device.address)
                    ) {
                        model.toggle(device)
                    }
                    if device.hasParts {
                        DeviceParts(device: device)
                    }
                }
                if !report.disconnected.isEmpty {
                    SectionLabel(text: "自分のデバイス")
                    ForEach(report.disconnected) { device in
                        DisconnectedDeviceRow(
                            device: device,
                            isBusy: model.busyDevices.contains(device.address)
                        ) {
                            model.toggle(device)
                        }
                    }
                }
            }
        } else {
            status("Bluetooth の情報を取得しています")
        }
    }

    private func status(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 36)
    }
}

struct DeviceIcon: View {
    let kind: BluetoothDevice.Kind
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(Theme.raised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }

    private var symbol: String {
        switch kind {
        case .headphones:
            return "headphones"
        case .speaker:
            return "hifispeaker"
        case .keyboard:
            return "keyboard"
        case .mouse:
            return "computermouse"
        case .trackpad:
            return "rectangle.and.hand.point.up.left"
        case .gamepad:
            return "gamecontroller"
        case .phone:
            return "iphone"
        case .computer:
            return "laptopcomputer"
        case .display:
            return "display"
        case .other:
            return "dot.radiowaves.left.and.right"
        }
    }
}

struct ConnectedDeviceRow: View {
    let device: BluetoothDevice
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        HoverRow(height: 48, isEnabled: !isBusy, action: action) {
            DeviceIcon(kind: device.kind, tint: Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(isBusy ? "切断中" : "接続済み")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else if let percent = device.summaryBattery {
                Meter(percent: percent, color: Theme.color(for: ChargeLevel(percent: percent)))
                    .frame(width: 36)
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}

struct DisconnectedDeviceRow: View {
    let device: BluetoothDevice
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        HoverRow(height: 44, isEnabled: !isBusy, action: action) {
            DeviceIcon(kind: device.kind, tint: Theme.textSecondary)
            Text(device.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("未接続")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textDim)
            }
        }
    }
}

struct DeviceParts: View {
    let device: BluetoothDevice

    var body: some View {
        HStack(spacing: 12) {
            part("L", device.left)
            part("R", device.right)
            part("ケース", device.chargingCase)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }

    private func part(_ name: String, _ percent: Int?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 4)
                Text(percent.map { "\($0)%" } ?? "-")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
            }
            Meter(
                percent: percent ?? 0,
                color: Theme.color(for: ChargeLevel(percent: percent ?? 0)),
                height: 4
            )
        }
        .frame(maxWidth: .infinity)
    }
}

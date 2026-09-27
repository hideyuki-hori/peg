import PegCore
import SwiftUI

struct WiFiCard: View {
    @ObservedObject var model: ControlPanelModel

    var body: some View {
        PanelCard(spacing: 8) {
            CardHeader(title: "Wi-Fi") {
                Image(systemName: "wifi")
                    .font(.system(size: 12, weight: .medium))
            } trailing: {
                if model.wifi.isAvailable {
                    PanelToggle(isOn: model.wifi.isPoweredOn, label: "Wi-Fi", action: model.setWiFiPower)
                }
            }
            content
            if let message = model.wifiMessage {
                MessageText(text: message)
            }
            PanelDivider()
            LinkRow(symbol: "gearshape", title: "Wi-Fi 設定を開く") {
                model.open(.wifi)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.wifi.isAvailable {
            status("Wi-Fi を利用できません")
        } else if !model.wifi.isPoweredOn {
            status("Wi-Fi はオフです")
        } else {
            current
            if model.locationAccess != .granted {
                NoticeBox(
                    symbol: "location",
                    tint: model.locationAccess == .denied ? Theme.coral : Theme.textSecondary,
                    title: "位置情報の許可が必要です",
                    detail: "ネットワーク名の表示に使います",
                    buttonTitle: model.locationAccess == .denied ? "設定" : "許可",
                    isProminent: model.locationAccess != .denied,
                    action: model.requestLocationAccess
                )
            } else if !model.wifi.known.isEmpty {
                SectionLabel(text: "既知のネットワーク")
                ForEach(model.wifi.known) { network in
                    HoverRow(isEnabled: model.joiningNetwork == nil, action: { model.join(network) }) {
                        Image(systemName: "wifi", variableValue: network.strength)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 16)
                        Text(network.ssid)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if model.joiningNetwork == network.ssid {
                            ProgressView()
                                .controlSize(.small)
                        } else if network.isSecure {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textDim)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var current: some View {
        if model.wifi.isConnected {
            SectionLabel(text: "接続中")
            HStack(spacing: 10) {
                Image(systemName: "wifi", variableValue: model.wifi.strength)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 16)
                Text(model.wifi.ssid ?? "接続中のネットワーク")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if model.wifi.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textDim)
                }
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Theme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        } else {
            status("ネットワークに接続していません")
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

import PegCore
import SwiftUI

struct BatteryCard: View {
    @ObservedObject var model: ControlPanelModel

    var body: some View {
        PanelCard {
            if let report = model.battery {
                CardHeader(title: "バッテリー") {
                    Image(systemName: symbol(for: report))
                        .font(.system(size: 13))
                } trailing: {
                    Text(report.stateText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(report.state == .onBattery ? Theme.textSecondary : Theme.green)
                }
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(report.percent))
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .kerning(-1)
                        .foregroundStyle(Theme.textPrimary)
                    Text("%")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(report.remainingText)
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        Text(report.sourceText)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Meter(percent: report.percent, color: Theme.color(for: report.level), height: 8)
                if let health = report.healthPercent {
                    HStack {
                        Text("バッテリーの状態")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 8)
                        Text("最大容量 \(health)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(height: 20)
                }
            } else {
                CardHeader(title: "バッテリー") {
                    Image(systemName: "battery.0percent")
                        .font(.system(size: 13))
                } trailing: {
                    EmptyView()
                }
                Text("バッテリー情報を取得できません")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            LinkRow(symbol: "gearshape", title: "バッテリー設定を開く") {
                model.open(.battery)
            }
        }
    }

    private func symbol(for report: BatteryReport) -> String {
        if report.state != .onBattery {
            return "battery.100percent.bolt"
        }
        if report.percent > 87 {
            return "battery.100percent"
        }
        if report.percent > 62 {
            return "battery.75percent"
        }
        if report.percent > 37 {
            return "battery.50percent"
        }
        if report.percent > 12 {
            return "battery.25percent"
        }
        return "battery.0percent"
    }
}

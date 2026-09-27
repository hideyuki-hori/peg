import PegCore
import SwiftUI

struct ControlPanelView: View {
    static let width: CGFloat = 760
    static let preferredHeight: CGFloat = 1002

    @ObservedObject var model: ControlPanelModel

    var body: some View {
        VStack(spacing: 0) {
            header
            PanelDivider()
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    CalendarCard(model: model)
                    BatteryCard(model: model)
                }
                .frame(width: 316)
                ScrollView {
                    VStack(spacing: 16) {
                        WiFiCard(model: model)
                        BluetoothCard(model: model)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .frame(width: ControlPanelView.width)
        .frame(maxHeight: .infinity)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text(ClockFormat.header(model.now))
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .kerning(-0.5)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            QuitButton(action: model.quit)
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
    }
}

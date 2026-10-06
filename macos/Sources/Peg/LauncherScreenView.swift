import PegCore
import SwiftUI

struct LauncherScreenView: View {
    @ObservedObject var model: LauncherModel

    var body: some View {
        let layout = model.layout
        ZStack(alignment: .topLeading) {
            Color.clear
            LauncherView(model: model)
                .floatingShadow()
                .offset(x: layout.launcherX, y: layout.launcherY)
        }
        .frame(width: layout.width, height: layout.height, alignment: .topLeading)
        .preferredColorScheme(.dark)
    }
}

struct SideCards: View {
    @ObservedObject var panel: ControlPanelModel
    let launcher: LauncherModel
    let layout: LauncherLayout

    var body: some View {
        if let todoHeight = layout.todoHeight {
            TodoCard(model: panel, launcher: launcher)
                .frame(width: LauncherLayout.launcherWidth, height: todoHeight)
                .floatingShadow()
                .offset(x: layout.launcherX, y: layout.todoY)
        }
        if let clockY = layout.clockY {
            ClockCard(panel: panel)
                .frame(width: LauncherLayout.launcherWidth, height: LauncherLayout.clockHeight)
                .floatingShadow()
                .offset(x: layout.launcherX, y: clockY)
        }
        if let cardWidth = layout.cardWidth {
            column {
                BatteryCard(model: panel)
            }
            .frame(width: cardWidth, height: layout.columnHeight, alignment: .top)
            .offset(x: layout.leftX, y: layout.columnY)
            column {
                WiFiCard(model: panel)
                BluetoothCard(model: panel)
            }
            .frame(width: cardWidth, height: layout.columnHeight, alignment: .top)
            .offset(x: layout.rightX, y: layout.columnY)
        }
    }

    private func column<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: LauncherLayout.spacing) {
                content()
            }
            .floatingShadow()
        }
        .scrollClipDisabled()
        .scrollBounceBehavior(.basedOnSize)
    }
}

struct ClockCard: View {
    @ObservedObject var panel: ControlPanelModel

    var body: some View {
        HStack {
            Text(ClockFormat.header(panel.now))
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .kerning(-0.4)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            QuitButton(action: panel.quit)
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

extension View {
    func floatingShadow() -> some View {
        shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
    }
}

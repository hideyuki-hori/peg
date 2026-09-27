import SwiftUI

struct PanelCard<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

struct CardHeader<Icon: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let icon: Icon
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            icon
                .foregroundStyle(Theme.accent)
                .frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
        .frame(height: 20)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.4)
            .foregroundStyle(Theme.textDim)
    }
}

struct PanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }
}

struct PanelToggle: View {
    let isOn: Bool
    let label: String
    let action: (Bool) -> Void

    var body: some View {
        Button {
            action(!isOn)
        } label: {
            Capsule()
                .fill(isOn ? Theme.accent : Theme.border)
                .frame(width: 36, height: 20)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .padding(2)
                }
                .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "オン" : "オフ")
    }
}

struct Meter: View {
    let percent: Int
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Theme.border)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
                }
        }
        .frame(height: height)
    }
}

struct HoverRow<Content: View>: View {
    var height: CGFloat = 36
    var isHighlighted = false
    var isEnabled = true
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                content
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 }
    }

    private var fill: Color {
        if isHighlighted {
            return Theme.accentSoft
        }
        if isHovering, isEnabled {
            return Theme.raised
        }
        return Color.clear
    }
}

struct LinkRow: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        HoverRow(height: 32, action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textDim)
        }
    }
}

struct NoticeBox: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let buttonTitle: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isProminent ? Color.white : Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(isProminent ? Theme.accent : Theme.border)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.raised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }
}

struct MessageText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.coral)
            .padding(.horizontal, 10)
    }
}

struct QuitButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                Text("終了")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isHovering ? Theme.coral : Theme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(isHovering ? Theme.coral.opacity(0.6) : Theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Peg を終了")
    }
}

struct BluetoothMark: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * unit, y: rect.midY - 12 * unit)
        let points: [(CGFloat, CGFloat)] = [(7, 7), (17, 17), (12, 22), (12, 2), (17, 7), (7, 17)]
        var path = Path()
        for (index, point) in points.enumerated() {
            let target = CGPoint(x: origin.x + point.0 * unit, y: origin.y + point.1 * unit)
            if index == 0 {
                path.move(to: target)
            } else {
                path.addLine(to: target)
            }
        }
        return path
    }
}

struct BluetoothIcon: View {
    var body: some View {
        BluetoothMark()
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }
}

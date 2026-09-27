import PegCore
import SwiftUI

enum Theme {
    static let background = Color(hex: 0x0B0B0E)
    static let surface = Color(hex: 0x16161A)
    static let raised = Color(hex: 0x1E1E24)
    static let border = Color(hex: 0x2A2A31)
    static let accent = Color(hex: 0x6366F1)
    static let accentSoft = Color(hex: 0x6366F1).opacity(0.28)
    static let saturday = Color(hex: 0x8B8DF5)
    static let green = Color(hex: 0x32D583)
    static let coral = Color(hex: 0xE85A4F)
    static let amber = Color(hex: 0xFFB547)
    static let textPrimary = Color(hex: 0xFAFAF9)
    static let textSecondary = Color(hex: 0x8E8E98)
    static let textDim = Color(hex: 0x5C5C66)
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16

    static func color(for level: ChargeLevel) -> Color {
        switch level {
        case .low:
            return coral
        case .medium:
            return amber
        case .high:
            return green
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

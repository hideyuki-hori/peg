import SwiftUI

enum Theme {
    static let background = Color(hex: 0x0B0B0E)
    static let surface = Color(hex: 0x16161A)
    static let border = Color(hex: 0x2A2A31)
    static let accent = Color(hex: 0x6366F1)
    static let textPrimary = Color(hex: 0xFAFAF9)
    static let textSecondary = Color(hex: 0x8E8E98)
    static let radiusSmall: CGFloat = 8
    static let radiusLarge: CGFloat = 16
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

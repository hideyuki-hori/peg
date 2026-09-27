import Foundation

public struct LauncherLayout: Equatable, Sendable {
    public static let launcherWidth = 640.0
    public static let launcherHeight = 420.0
    public static let clockHeight = 64.0
    public static let spacing = 16.0
    public static let gap = 24.0
    public static let margin = 16.0
    public static let maxCardWidth = 340.0
    public static let minCardWidth = 280.0
    public static let maxTodoHeight = 320.0
    public static let minTodoHeight = 170.0

    public let width: Double
    public let height: Double
    public let launcherX: Double
    public let launcherY: Double
    public let clockY: Double?
    public let cardWidth: Double?
    public let columnY: Double
    public let columnHeight: Double
    public let todoY: Double
    public let todoHeight: Double?

    public init(width: Double = LauncherLayout.launcherWidth, height: Double = LauncherLayout.launcherHeight) {
        self.width = width
        self.height = height
        launcherX = max(((width - LauncherLayout.launcherWidth) / 2).rounded(.down), 0)
        launcherY = max(((height - LauncherLayout.launcherHeight) * 0.38).rounded(.down), 0)
        let clock = launcherY - LauncherLayout.spacing - LauncherLayout.clockHeight
        clockY = clock >= LauncherLayout.margin ? clock : nil
        let side = launcherX - LauncherLayout.gap - LauncherLayout.margin
        cardWidth = side >= LauncherLayout.minCardWidth ? min(side, LauncherLayout.maxCardWidth) : nil
        columnY = clockY ?? launcherY
        columnHeight = max(height - columnY - LauncherLayout.margin, 0)
        todoY = launcherY + LauncherLayout.launcherHeight + LauncherLayout.spacing
        let room = height - todoY - LauncherLayout.margin
        todoHeight = room >= LauncherLayout.minTodoHeight ? min(room, LauncherLayout.maxTodoHeight) : nil
    }

    public var leftX: Double {
        launcherX - LauncherLayout.gap - (cardWidth ?? 0)
    }

    public var rightX: Double {
        launcherX + LauncherLayout.launcherWidth + LauncherLayout.gap
    }
}

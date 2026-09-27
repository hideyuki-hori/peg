import Foundation

public struct DoubleTapDetector {
    public enum Input {
        case down
        case up
        case other
    }

    public let maxHold: TimeInterval
    public let maxInterval: TimeInterval
    private var downAt: TimeInterval?
    private var lastTapAt: TimeInterval?

    public init(maxHold: TimeInterval = 0.3, maxInterval: TimeInterval = 0.4) {
        self.maxHold = maxHold
        self.maxInterval = maxInterval
    }

    public mutating func reset() {
        downAt = nil
        lastTapAt = nil
    }

    public mutating func handle(_ input: Input, at time: TimeInterval) -> Bool {
        switch input {
        case .other:
            reset()
            return false
        case .down:
            downAt = time
            return false
        case .up:
            guard let pressedAt = downAt else { return false }
            downAt = nil
            guard time - pressedAt <= maxHold else {
                lastTapAt = nil
                return false
            }
            if let previous = lastTapAt, time - previous <= maxInterval {
                lastTapAt = nil
                return true
            }
            lastTapAt = time
            return false
        }
    }
}

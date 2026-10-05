import AppKit
import PegCore

@MainActor
final class DoubleCommandMonitor {
    private var detector = DoubleTapDetector()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let handler: () -> Void
    private let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown]
    private let modifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control, .function]

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func reset() {
        detector.reset()
    }

    private func handle(_ event: NSEvent) {
        if detector.handle(input(for: event), at: event.timestamp) {
            handler()
        }
    }

    private func input(for event: NSEvent) -> DoubleTapDetector.Input {
        guard event.type == .flagsChanged else { return .other }
        let flags = event.modifierFlags.intersection(modifiers)
        if flags == .command {
            return .down
        }
        if flags.isEmpty {
            return .up
        }
        return .other
    }
}

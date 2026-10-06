import AppKit

final class BackdropView: NSView {
    var onClick: () -> Void = {}

    override func mouseDown(with event: NSEvent) {
        onClick()
    }

    override func rightMouseDown(with event: NSEvent) {
        onClick()
    }
}

@MainActor
final class Backdrop {
    static let level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
    static let panelLevel = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)

    private var windows: [NSWindow] = []

    func show(onClick: @escaping () -> Void) {
        guard windows.isEmpty else { return }
        for screen in NSScreen.screens {
            let window = makeWindow(on: screen, onClick: onClick)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
        }
        windows = []
    }

    private func makeWindow(on screen: NSScreen, onClick: @escaping () -> Void) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = Backdrop.level
        window.appearance = NSAppearance(named: .darkAqua)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let view = BackdropView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.autoresizingMask = [.width, .height]
        view.onClick = onClick
        window.contentView = view
        window.setFrame(screen.frame, display: false)
        return window
    }
}

import AppKit
import SwiftUI

@MainActor
final class ControlPanelController: NSObject, NSWindowDelegate {
    let model = ControlPanelModel()
    private let panel: LauncherPanel
    private let backdrop = Backdrop()
    private var keyMonitor: Any?

    override init() {
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: ControlPanelView.width, height: ControlPanelView.preferredHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = Backdrop.panelLevel
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ControlPanelView(model: model))
        panel.delegate = self
        model.onClose = { [weak self] in
            self?.hide()
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        model.start()
        position()
        backdrop.show { [weak self] in
            self?.hide()
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        backdrop.hide()
        model.stop()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let height = min(ControlPanelView.preferredHeight, frame.height - 32)
        let x = frame.midX - ControlPanelView.width / 2
        let y = frame.midY - height / 2
        panel.setFrame(NSRect(x: x, y: y, width: ControlPanelView.width, height: height), display: true)
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard event.window === panel else { return event }
        if event.keyCode == 53 {
            hide()
            return nil
        }
        return event
    }
}

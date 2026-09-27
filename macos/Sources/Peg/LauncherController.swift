import AppKit
import PegCore
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class LauncherController: NSObject, NSWindowDelegate {
    let model = LauncherModel()
    private let panel: LauncherPanel
    private let clipboard: ClipboardMonitor
    private let backdrop = Backdrop()
    private var keyMonitor: Any?

    init(clipboard: ClipboardMonitor) {
        self.clipboard = clipboard
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
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
        panel.contentView = NSHostingView(rootView: LauncherView(model: model))
        panel.delegate = self
        model.onLaunch = { [weak self] entry in
            self?.launch(entry)
        }
        model.onPick = { [weak self] entry in
            self?.pick(entry)
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    func toggle(mode: LauncherModel.Mode) {
        if panel.isVisible, model.mode == mode {
            hide()
        } else {
            show(mode: mode)
        }
    }

    func show(mode: LauncherModel.Mode) {
        model.present(mode: mode, entries: AppList.load(from: PegPaths.appsFile), clips: clipboard.entries)
        position()
        backdrop.show { [weak self] in
            self?.hide()
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
        backdrop.hide()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.minY + (frame.height - size.height) * 0.62
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func launch(_ entry: AppEntry) {
        hide()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: entry.url, configuration: configuration) { _, error in
            if let error {
                NSLog("Peg: failed to open %@: %@", entry.url.path, error.localizedDescription)
            }
        }
    }

    private func pick(_ entry: ClipEntry) {
        clipboard.copy(entry)
        hide()
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard event.window === panel else { return event }
        if let context = NSTextInputContext.current, context.client.hasMarkedText() {
            return event
        }
        let control = event.modifierFlags.contains(.control)
        switch event.keyCode {
        case 53:
            hide()
            return nil
        case 36, 76:
            model.activateSelection()
            return nil
        case 125:
            model.moveSelection(by: 1)
            return nil
        case 126:
            model.moveSelection(by: -1)
            return nil
        case 45 where control:
            model.moveSelection(by: 1)
            return nil
        case 35 where control:
            model.moveSelection(by: -1)
            return nil
        default:
            return event
        }
    }
}

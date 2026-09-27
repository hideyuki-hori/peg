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
    let panelModel = ControlPanelModel()
    private let panel: LauncherPanel
    private let clipboard: ClipboardMonitor
    private let backdrop = Backdrop()
    private var keyMonitor: Any?

    init(clipboard: ClipboardMonitor) {
        self.clipboard = clipboard
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: LauncherLayout.launcherWidth, height: LauncherLayout.launcherHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = Backdrop.panelLevel
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: LauncherScreenView(model: model, panel: panelModel))
        panel.delegate = self
        panelModel.onClose = { [weak self] in
            self?.hide()
        }
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
        refreshCards(for: mode)
    }

    func hide() {
        panel.orderOut(nil)
        backdrop.hide()
        panelModel.stop()
    }

    private func refreshCards(for mode: LauncherModel.Mode) {
        let layout = model.layout
        guard mode == .apps, layout.cardWidth != nil || layout.clockY != nil || layout.todoHeight != nil else {
            panelModel.stop()
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible, self.model.mode == .apps else { return }
            self.panelModel.start()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        model.layout = LauncherLayout(width: frame.width, height: frame.height)
        panel.setFrame(frame, display: true)
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
        let command = event.modifierFlags.contains(.command)
        if event.keyCode == 45, command, model.mode == .apps, model.layout.todoHeight != nil {
            model.focus = .todo
            return nil
        }
        if model.focus == .todo {
            guard event.keyCode == 53 else { return event }
            model.focus = .search
            return nil
        }
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

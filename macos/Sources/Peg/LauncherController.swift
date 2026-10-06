import AppKit
import PegCore
import PegMenu
import PegNotes
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
    private let notes: NoteStore
    private let sticky: StickyController
    private let backdrop = Backdrop()
    private var keyMonitor: Any?
    private var menuSnapshot: MenuSnapshot?

    init(clipboard: ClipboardMonitor, notes: NoteStore, sticky: StickyController) {
        self.clipboard = clipboard
        self.notes = notes
        self.sticky = sticky
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
        panel.contentView = NSHostingView(rootView: LauncherScreenView(model: model))
        panel.delegate = self
        model.onLaunch = { [weak self] entry in
            self?.launch(entry)
        }
        model.onPick = { [weak self] entry in
            self?.pick(entry)
        }
        model.onCopy = { [weak self] text in
            self?.pick(ClipEntry(text: text))
        }
        model.onMenu = { [weak self] item in
            self?.press(item)
        }
        model.onNote = { [weak self] id in
            self?.hide()
            self?.sticky.open(id)
        }
        model.onNewNote = { [weak self] in
            self?.hide()
            self?.sticky.createAndShow()
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
        if mode == .apps {
            loadNotes()
            loadMenu()
        }
    }

    private func loadNotes() {
        let presentation = model.presentation
        Task {
            let notes = await notes.list()
            guard model.presentation == presentation else { return }
            model.notes = notes
        }
    }

    private func loadMenu() {
        let presentation = model.presentation
        menuSnapshot = nil
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        guard Accessibility.isTrusted else {
            model.menuMessage = "メニュー検索にはアクセシビリティの許可が必要です"
            NSLog("Peg: menu search skipped: accessibility is not trusted")
            return
        }
        let name = app.localizedName ?? "?"
        Task {
            let snapshot = await MenuReader.read(pid: app.processIdentifier)
            guard model.presentation == presentation, panel.isVisible else { return }
            menuSnapshot = snapshot
            model.menuItems = snapshot?.items ?? []
            if snapshot == nil {
                model.menuMessage = "\(name) のメニューを読み取れませんでした"
                NSLog("Peg: menu search: could not read the menu bar of %@ (pid %d)", name, app.processIdentifier)
            } else {
                NSLog("Peg: menu search: %d items from %@", snapshot?.items.count ?? 0, name)
            }
        }
    }

    private func press(_ item: MenuItem) {
        hide()
        guard let snapshot = menuSnapshot else { return }
        Task {
            if !(await snapshot.press(item)) {
                NSLog("Peg: failed to press menu item %@", item.title)
            }
        }
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
        if event.keyCode == 12, command {
            NSApp.terminate(nil)
            return nil
        }
        if event.keyCode == 48 {
            model.toggleHintMode()
            return nil
        }
        if model.hintMode, let handled = handleHintKey(event) {
            return handled
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

    private func handleHintKey(_ event: NSEvent) -> NSEvent?? {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags.isEmpty else { return nil }
        switch event.keyCode {
        case 53:
            model.toggleHintMode()
            return .some(nil)
        case 51:
            model.eraseHint()
            return .some(nil)
        default:
            break
        }
        guard let character = event.charactersIgnoringModifiers?.first, HintLabels.homeRow.contains(character) else {
            return nil
        }
        model.typeHint(character)
        return .some(nil)
    }
}

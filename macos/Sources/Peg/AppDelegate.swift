import AppKit
import Carbon.HIToolbox
import PegCore
import PegNotes

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboard: ClipboardMonitor?
    private var launcher: LauncherController?
    private var hotKey: HotKey?
    private var sticky: StickyController?
    private var doubleCommand: DoubleModifierMonitor?
    private var doubleFunction: DoubleModifierMonitor?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try PegPaths.prepare()
        } catch {
            NSLog("Peg: failed to prepare config directory: %@", error.localizedDescription)
        }

        let clipboard = ClipboardMonitor()
        clipboard.start()
        self.clipboard = clipboard

        let memoDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("memo")
        let stickyStateFile = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/peg/notes/stickies.json")
        let noteStore = NoteStore(directory: memoDirectory)
        let sticky = StickyController(store: noteStore, stateStore: StickyStateStore(file: stickyStateFile))
        self.sticky = sticky

        let launcher = LauncherController(clipboard: clipboard, notes: noteStore, sticky: sticky)
        self.launcher = launcher

        let doubleCommand = DoubleModifierMonitor(modifier: .command) { [weak launcher] in
            launcher?.toggle(mode: .clipboard)
        }
        doubleCommand.start()
        self.doubleCommand = doubleCommand

        hotKey = HotKey(keyCode: kVK_Space, modifiers: cmdKey) { [weak launcher, weak doubleCommand] in
            doubleCommand?.reset()
            launcher?.toggle(mode: .apps)
        }
        if hotKey == nil {
            NSLog("Peg: failed to register cmd+space")
        }

        let doubleFunction = DoubleModifierMonitor(modifier: .function) { [weak launcher, weak sticky] in
            launcher?.hide()
            sticky?.toggle()
        }
        doubleFunction.start()
        self.doubleFunction = doubleFunction

        let statusItem = StatusItemController { [weak launcher, weak doubleCommand] in
            doubleCommand?.reset()
            launcher?.toggle(mode: .apps)
        }
        statusItem.start()
        self.statusItem = statusItem

        NSApp.mainMenu = makeMainMenu()
        Accessibility.requestAccess()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let sticky else { return .terminateNow }
        Task {
            await sticky.finish()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        return mainMenu
    }
}

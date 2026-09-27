import AppKit
import Carbon.HIToolbox
import PegCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboard: ClipboardMonitor?
    private var launcher: LauncherController?
    private var controlPanel: ControlPanelController?
    private var hotKey: HotKey?
    private var controlPanelHotKey: HotKey?
    private var doubleCommand: DoubleCommandMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try PegPaths.prepare()
        } catch {
            NSLog("Peg: failed to prepare config directory: %@", error.localizedDescription)
        }

        let clipboard = ClipboardMonitor()
        clipboard.start()
        self.clipboard = clipboard

        let launcher = LauncherController(clipboard: clipboard)
        self.launcher = launcher

        let doubleCommand = DoubleCommandMonitor { [weak launcher] in
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

        let controlPanel = ControlPanelController()
        self.controlPanel = controlPanel
        controlPanelHotKey = HotKey(keyCode: kVK_Space, modifiers: cmdKey | shiftKey) { [weak controlPanel, weak doubleCommand] in
            doubleCommand?.reset()
            controlPanel?.toggle()
        }
        if controlPanelHotKey == nil {
            NSLog("Peg: failed to register cmd+shift+space")
        }

        NSApp.mainMenu = makeMainMenu()
        Accessibility.requestAccess()
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        return mainMenu
    }
}

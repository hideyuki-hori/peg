import AppKit
import Carbon.HIToolbox
import PegCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboard: ClipboardMonitor?
    private var launcher: LauncherController?
    private var hotKey: HotKey?
    private var doubleCommand: DoubleCommandMonitor?
    private var statusItem: NSStatusItem?

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

        NSApp.mainMenu = makeMainMenu()
        statusItem = makeStatusItem()
        Accessibility.requestAccess()
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Peg")
        let menu = NSMenu()
        menu.addItem(makeItem("アプリを開く", action: #selector(showApps)))
        menu.addItem(makeItem("クリップボード履歴", action: #selector(showClipboard)))
        menu.addItem(.separator())
        menu.addItem(makeItem("設定フォルダを開く", action: #selector(openConfig)))
        menu.addItem(makeItem("アクセシビリティ設定を開く", action: #selector(openAccessibility)))
        menu.addItem(.separator())
        menu.addItem(makeItem("Peg を終了", action: #selector(quit)))
        item.menu = menu
        return item
    }

    private func makeItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
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

    @objc private func showApps() {
        launcher?.show(mode: .apps)
    }

    @objc private func showClipboard() {
        launcher?.show(mode: .clipboard)
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(PegPaths.configDirectory)
    }

    @objc private func openAccessibility() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

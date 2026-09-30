import AppKit
import SwiftUI

@MainActor
final class NoteEditorController: NSObject {
    private let model = NoteEditorModel()
    private let window: NSWindow
    private var keyMonitor: Any?

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "Peg"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Theme.surface)
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 620, height: 400)
        window.contentView = NSHostingView(rootView: NoteEditorView(model: model))
        window.center()
        window.setFrameAutosaveName("PegNoteEditor")
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    func toggle() {
        if window.isVisible, window.isKeyWindow {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        model.open()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags == .command else { return event }
        switch event.keyCode {
        case 1:
            model.save()
            return nil
        case 45:
            model.beginNaming()
            return nil
        case 13:
            window.orderOut(nil)
            return nil
        default:
            return event
        }
    }
}

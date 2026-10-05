import AppKit
import PegNotes

@MainActor
final class StickyController: NSObject {
    private static let defaultSize = NSSize(width: 340, height: 320)
    private let store: NoteStore
    private let stateStore: StickyStateStore
    private var windows: [StickyWindow] = []
    private var focused: String?
    private var isVisible = false
    private var isRestored = false
    private var isWorking = false
    private var stateTask: Task<Void, Never>?
    private var keyMonitor: Any?

    init(store: NoteStore, stateStore: StickyStateStore) {
        self.store = store
        self.stateStore = stateStore
        super.init()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    func toggle() {
        if !isVisible {
            run { await self.show() }
        } else if let target = windows.first(where: { $0.id == focused }) ?? windows.last, !windows.contains(where: { $0.panel.isKeyWindow }) {
            target.focus()
        } else {
            run { await self.hideAll() }
        }
    }

    func finish() async {
        await closeEmptyWindows()
        stateTask?.cancel()
        await saveState()
    }

    private func run(_ work: @escaping @MainActor () async -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await work()
            isWorking = false
        }
    }

    private func show() async {
        if !isRestored {
            isRestored = true
            let state = await stateStore.load()
            focused = state.focused
            for placement in state.placements {
                let frame = NSRect(x: placement.x, y: placement.y, width: placement.width, height: placement.height)
                await open(placement.id, frame: isOnScreen(frame) ? frame : nil)
            }
        } else {
            for window in windows where !(await window.refresh()) {
                remove(window)
            }
        }
        if windows.isEmpty {
            if let latest = await store.list().last {
                await open(latest.id, frame: nil)
            } else {
                await create()
            }
        }
        isVisible = true
        for window in windows {
            window.panel.orderFront(nil)
        }
        (windows.first { $0.id == focused } ?? windows.last)?.focus()
        scheduleStateSave()
    }

    private func hideAll() async {
        isVisible = false
        for window in windows {
            window.panel.orderOut(nil)
        }
        await closeEmptyWindows()
        scheduleStateSave()
    }

    private func closeEmptyWindows() async {
        for window in windows where await window.finish() {
            remove(window)
        }
    }

    @discardableResult
    private func open(_ id: String, frame: NSRect?) async -> StickyWindow? {
        if let existing = windows.first(where: { $0.id == id }) {
            return existing
        }
        guard let note = await store.read(id) else { return nil }
        let window = StickyWindow(note: note, frame: frame ?? nextFrame(), store: store)
        window.onFrameChange = { [weak self] in
            self?.scheduleStateSave()
        }
        window.onFocus = { [weak self] in
            self?.focused = id
        }
        windows.append(window)
        return window
    }

    private func create() async {
        do {
            let note = try await store.create()
            let window = await open(note.id, frame: nil)
            focused = note.id
            if isVisible {
                window?.focus()
            }
            scheduleStateSave()
        } catch {
            NSLog("Peg: failed to create note: %@", error.localizedDescription)
        }
    }

    private func close(_ window: StickyWindow) async {
        window.panel.orderOut(nil)
        _ = await window.finish()
        let index = windows.firstIndex { $0 === window } ?? 0
        remove(window)
        focusNeighbor(at: index)
    }

    private func delete(_ window: StickyWindow) async {
        window.cancelPendingSave()
        do {
            try await store.delete(window.id)
        } catch {
            NSLog("Peg: failed to delete note: %@", error.localizedDescription)
            return
        }
        window.panel.orderOut(nil)
        let index = windows.firstIndex { $0 === window } ?? 0
        remove(window)
        focusNeighbor(at: index)
    }

    private func remove(_ window: StickyWindow) {
        window.panel.orderOut(nil)
        windows.removeAll { $0 === window }
        scheduleStateSave()
    }

    private func focusNeighbor(at index: Int) {
        guard !windows.isEmpty else {
            isVisible = false
            return
        }
        windows[min(index, windows.count - 1)].focus()
    }

    private func moveFocus(from window: StickyWindow, by delta: Int) {
        guard let index = windows.firstIndex(where: { $0 === window }) else { return }
        let next = ((index + delta) % windows.count + windows.count) % windows.count
        windows[next].focus()
    }

    private func nextFrame() -> NSRect {
        let size = StickyController.defaultSize
        let anchor = windows.first { $0.panel.isKeyWindow } ?? windows.last
        if let anchor {
            let frame = anchor.panel.frame
            let shifted = NSRect(x: frame.minX + 28, y: frame.maxY - 28 - size.height, width: size.width, height: size.height)
            if isOnScreen(shifted) {
                return shifted
            }
        }
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSRect(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24, width: size.width, height: size.height)
    }

    private func isOnScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersection(frame).width >= 80 && $0.visibleFrame.intersection(frame).height >= 80 }
    }

    private func scheduleStateSave() {
        stateTask?.cancel()
        stateTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.saveState()
        }
    }

    private func saveState() async {
        guard isRestored else { return }
        do {
            try await stateStore.save(StickyState(placements: windows.map(\.placement), focused: focused))
        } catch {
            NSLog("Peg: failed to save sticky state: %@", error.localizedDescription)
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard let window = windows.first(where: { $0.panel === event.window }), !window.textView.hasMarkedText() else {
            return event
        }
        let textView = window.textView
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if flags.isEmpty, event.keyCode == 53 {
            run { await self.hideAll() }
            return nil
        }
        if flags == [.command, .shift] {
            if event.keyCode == 51 {
                run { await self.delete(window) }
                return nil
            }
            if key == "z" {
                textView.undoManager?.redo()
                return nil
            }
            return event
        }
        guard flags == .command else { return event }
        switch key {
        case "n":
            run { await self.create() }
        case "[", "「":
            moveFocus(from: window, by: -1)
        case "]", "」":
            moveFocus(from: window, by: 1)
        case "w":
            run { await self.close(window) }
        case "q":
            NSApp.terminate(nil)
        case "z":
            textView.undoManager?.undo()
        case "a":
            textView.selectAll(nil)
        case "c":
            textView.copy(nil)
        case "x":
            textView.cut(nil)
        case "v":
            textView.pasteAsPlainText(nil)
        default:
            return event
        }
        return nil
    }
}

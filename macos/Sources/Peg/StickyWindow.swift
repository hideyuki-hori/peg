import AppKit
import PegNotes

final class StickyPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class StickyWindow: NSObject, NSTextViewDelegate, NSWindowDelegate {
    let id: String
    let panel: StickyPanel
    let textView = NSTextView()
    var onFrameChange: () -> Void = {}
    var onFocus: () -> Void = {}
    private let store: NoteStore
    private var savedText: String
    private var saveTask: Task<Void, Never>?

    init(note: Note, frame: NSRect, store: NoteStore) {
        id = note.id
        savedText = note.text
        self.store = store
        panel = StickyPanel(
            contentRect: frame,
            styleMask: [.titled, .fullSizeContentView, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel(frame: frame)
        configureContent()
        textView.string = note.text
        restyle()
    }

    var placement: StickyPlacement {
        let frame = panel.frame
        return StickyPlacement(id: id, x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
    }

    func focus() {
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
    }

    func refresh() async -> Bool {
        guard let note = await store.read(id) else { return false }
        if textView.string == savedText, note.text != savedText {
            textView.string = note.text
            textView.undoManager?.removeAllActions()
            restyle()
        }
        savedText = note.text
        return true
    }

    func flush() async {
        saveTask?.cancel()
        let text = textView.string
        guard text != savedText else { return }
        do {
            try await store.write(Note(id: id, text: text))
            savedText = text
        } catch {
            NSLog("Peg: failed to save note: %@", error.localizedDescription)
        }
    }

    func finish() async -> Bool {
        await flush()
        return (try? await store.removeIfEmpty(id)) == true
    }

    func cancelPendingSave() {
        saveTask?.cancel()
    }

    func textDidChange(_ notification: Notification) {
        guard !textView.hasMarkedText() else { return }
        restyle()
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    func windowDidMove(_ notification: Notification) {
        onFrameChange()
    }

    func windowDidResize(_ notification: Notification) {
        onFrameChange()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        onFocus()
    }

    private func configurePanel(frame: NSRect) {
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor(Theme.surface)
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.minSize = NSSize(width: 220, height: 140)
        panel.setFrame(frame, display: false)
        panel.delegate = self
    }

    private func configureContent() {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.insertionPointColor = NSColor(Theme.accent)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 14, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.typingAttributes = MarkdownHighlighter.baseAttributes
        textView.delegate = self

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        panel.contentView = container
    }

    private func restyle() {
        guard let storage = textView.textStorage else { return }
        MarkdownHighlighter.apply(to: storage)
        textView.typingAttributes = MarkdownHighlighter.baseAttributes
    }
}

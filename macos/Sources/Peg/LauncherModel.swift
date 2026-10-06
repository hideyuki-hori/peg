import AppKit
import PegCore
import PegMenu
import PegNotes

struct AppItem: Identifiable {
    let entry: AppEntry
    let icon: NSImage

    var id: String {
        entry.id
    }
}

struct LauncherRow: Identifiable {
    enum Content {
        case app(AppItem)
        case clip(ClipEntry)
        case calculation(Calculation)
        case menu(MenuItem)
        case note(NoteSummary)
        case newNote
    }

    let id: String
    let content: Content
}

@MainActor
final class LauncherModel: ObservableObject {
    enum Mode {
        case apps
        case clipboard
    }

    enum Focus {
        case search
        case todo
    }

    @Published var mode: Mode = .apps
    @Published var query = "" {
        didSet {
            selection = 0
        }
    }
    @Published var selection = 0
    @Published var presentation = 0
    @Published var hintMode = false
    @Published var hintInput = ""
    @Published var menuItems: [MenuItem] = []
    @Published var menuMessage: String?
    @Published var notes: [NoteSummary] = []
    @Published var layout = LauncherLayout()
    @Published var focus: Focus = .search
    @Published private(set) var apps: [AppItem] = []
    @Published private(set) var clips: [ClipEntry] = []

    var onLaunch: (AppEntry) -> Void = { _ in }
    var onPick: (ClipEntry) -> Void = { _ in }
    var onCopy: (String) -> Void = { _ in }
    var onMenu: (MenuItem) -> Void = { _ in }
    var onNote: (String) -> Void = { _ in }
    var onNewNote: () -> Void = {}

    var filteredApps: [AppItem] {
        Matcher.filter(apps, query: query) { $0.entry.name }
    }

    var filteredClips: [ClipEntry] {
        Matcher.filter(clips, query: query) { $0.text }
    }

    var filteredMenuItems: [MenuItem] {
        guard !query.isEmpty else { return [] }
        return Array(Matcher.filter(menuItems, query: query) { $0.title }.prefix(40))
    }

    var filteredNotes: [NoteSummary] {
        let matched = Matcher.filter(notes, query: query) { $0.title }
        return query.isEmpty ? Array(matched.suffix(8).reversed()) : Array(matched.prefix(20))
    }

    var rows: [LauncherRow] {
        switch mode {
        case .apps:
            var rows: [LauncherRow] = []
            if let calculation = Calculator.calculate(query) {
                rows.append(LauncherRow(id: "calculation", content: .calculation(calculation)))
            }
            rows += filteredApps.map { LauncherRow(id: "app:" + $0.id, content: .app($0)) }
            rows += filteredMenuItems.map { LauncherRow(id: "menu:" + $0.id, content: .menu($0)) }
            rows += filteredNotes.map { LauncherRow(id: "note:" + $0.id, content: .note($0)) }
            if query.isEmpty || Matcher.score(query: query, candidate: "新しい付箋") != nil {
                rows.append(LauncherRow(id: "new-note", content: .newNote))
            }
            return rows
        case .clipboard:
            return filteredClips.map { LauncherRow(id: "clip:" + $0.id.uuidString, content: .clip($0)) }
        }
    }

    var hints: [String] {
        HintLabels.make(count: count)
    }

    var count: Int {
        rows.count
    }

    func present(mode: Mode, entries: [AppEntry], clips: [ClipEntry]) {
        self.mode = mode
        self.clips = clips
        apps = entries
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
            .map { AppItem(entry: $0, icon: NSWorkspace.shared.icon(forFile: $0.url.path)) }
        query = ""
        selection = 0
        focus = .search
        hintMode = false
        hintInput = ""
        menuItems = []
        menuMessage = nil
        presentation += 1
    }

    func toggleHintMode() {
        hintMode.toggle()
        hintInput = ""
    }

    func typeHint(_ character: Character) {
        let input = hintInput + String(character)
        switch HintLabels.match(input, in: hints) {
        case .exact(let index):
            hintInput = ""
            activate(index)
        case .partial:
            hintInput = input
        case .none:
            break
        }
    }

    func eraseHint() {
        hintInput = String(hintInput.dropLast())
    }

    func moveSelection(by offset: Int) {
        guard count > 0 else { return }
        selection = (selection + offset + count) % count
    }

    func activate(_ index: Int) {
        let items = rows
        guard items.indices.contains(index) else { return }
        switch items[index].content {
        case .app(let item):
            onLaunch(item.entry)
        case .clip(let entry):
            onPick(entry)
        case .calculation(let calculation):
            onCopy(calculation.result)
        case .menu(let item):
            onMenu(item)
        case .note(let note):
            onNote(note.id)
        case .newNote:
            onNewNote()
        }
    }

    func activateSelection() {
        activate(selection)
    }
}

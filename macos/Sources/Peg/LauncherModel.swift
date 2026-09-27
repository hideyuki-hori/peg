import AppKit
import PegCore

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

    @Published var mode: Mode = .apps
    @Published var query = "" {
        didSet {
            selection = 0
        }
    }
    @Published var selection = 0
    @Published var presentation = 0
    @Published private(set) var apps: [AppItem] = []
    @Published private(set) var clips: [ClipEntry] = []

    var onLaunch: (AppEntry) -> Void = { _ in }
    var onPick: (ClipEntry) -> Void = { _ in }

    var filteredApps: [AppItem] {
        Matcher.filter(apps, query: query) { $0.entry.name }
    }

    var filteredClips: [ClipEntry] {
        Matcher.filter(clips, query: query) { $0.text }
    }

    var rows: [LauncherRow] {
        switch mode {
        case .apps:
            return filteredApps.map { LauncherRow(id: "app:" + $0.id, content: .app($0)) }
        case .clipboard:
            return filteredClips.map { LauncherRow(id: "clip:" + $0.id.uuidString, content: .clip($0)) }
        }
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
        presentation += 1
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
        }
    }

    func activateSelection() {
        activate(selection)
    }
}

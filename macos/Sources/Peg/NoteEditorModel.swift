import Foundation
import PegCore

@MainActor
final class NoteEditorModel: ObservableObject {
    private struct Document {
        var base: String?
        var text: String
    }

    @Published private(set) var rows: [NoteRow] = []
    @Published private(set) var rootName = ""
    @Published private(set) var isReady = false
    @Published private(set) var selected: String?
    @Published private(set) var loadedText = ""
    @Published private(set) var revision = 0
    @Published private(set) var isEditable = false
    @Published private(set) var dirty: Set<String> = []
    @Published private(set) var status = ""
    @Published private(set) var isSyncing = false
    @Published var draftName: String?

    private var root: URL?
    private var device = "mac"
    private var expanded: Set<String> = []
    private var documents: [String: Document] = [:]

    func open() {
        let config = PegConfig.load(from: PegPaths.configFile)
        let next = config.editorRoot()
        if next != root {
            root = next
            expanded = []
            documents = [:]
            dirty = []
            show(nil)
        }
        device = config.sync?.deviceName ?? "mac"
        rescan()
        sync()
    }

    func select(_ row: NoteRow) {
        if row.isDirectory {
            if expanded.contains(row.path) {
                expanded.remove(row.path)
            } else {
                expanded.insert(row.path)
            }
            rescan()
        } else {
            show(row.path)
        }
    }

    func edit(_ text: String) {
        guard let selected, var document = documents[selected] else { return }
        document.text = text
        documents[selected] = document
        mark(selected, isDirty: document.text != document.base)
    }

    func save() {
        guard let selected, let document = documents[selected], isEditable, let url = url(for: selected) else {
            sync()
            return
        }
        do {
            switch NoteSave.decide(base: document.base, disk: read(selected), text: document.text) {
            case .unchanged:
                break
            case .write:
                try write(document.text, to: url)
            case .conflict:
                let conflictPath = ConflictName.make(path: selected, device: device, stamp: ConflictName.stamp(Date()))
                guard let conflictURL = self.url(for: conflictPath) else { return }
                try write(document.text, to: conflictURL)
                documents[selected] = nil
                mark(selected, isDirty: false)
                show(selected)
                sync(prefix: "ほかで変更されていたため、編集内容を \(conflictPath) に保存しました。")
                return
            }
        } catch {
            status = "保存できませんでした"
            return
        }
        documents[selected] = Document(base: document.text, text: document.text)
        mark(selected, isDirty: false)
        sync(prefix: "保存しました。")
    }

    func beginNaming() {
        guard isReady else { return }
        draftName = ""
    }

    func cancelNaming() {
        draftName = nil
    }

    func commitNaming() {
        guard let input = draftName else { return }
        let directory = selected.map(NoteTree.parent(of:)) ?? ""
        guard let path = NoteName.path(for: input, in: directory), let url = url(for: path) else {
            status = "その名前は使えません"
            return
        }
        draftName = nil
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try write("", to: url)
            } catch {
                status = "ファイルを作成できませんでした"
                return
            }
        }
        expanded.formUnion(NoteTree.ancestors(of: path))
        rescan()
        show(path)
    }

    private func sync(prefix: String = "") {
        isSyncing = true
        Task {
            let outcome = await SyncService.shared.run()
            isSyncing = false
            status = prefix + (outcome?.message ?? "")
            if let outcome {
                NSLog("Peg: sync: %@", outcome.message)
            }
            reconcile()
        }
    }

    private func reconcile() {
        rescan()
        guard let selected, !dirty.contains(selected) else { return }
        guard let disk = read(selected) else {
            if url(for: selected).map({ FileManager.default.fileExists(atPath: $0.path) }) != true {
                documents[selected] = nil
                show(nil)
            }
            return
        }
        if documents[selected]?.base != disk {
            documents[selected] = nil
            show(selected)
        }
    }

    private func show(_ path: String?) {
        if let previous = selected, !dirty.contains(previous) {
            documents[previous] = nil
        }
        selected = path
        revision += 1
        guard let path else {
            loadedText = ""
            isEditable = false
            return
        }
        if let document = documents[path] {
            loadedText = document.text
            isEditable = true
            return
        }
        guard let text = read(path) else {
            loadedText = ""
            isEditable = false
            status = "テキストとして開けないファイルです"
            return
        }
        documents[path] = Document(base: text, text: text)
        loadedText = text
        isEditable = true
    }

    private func rescan() {
        guard let root else {
            isReady = false
            rootName = ""
            rows = []
            status = "config.json の vaultPath を設定してください"
            return
        }
        guard let subpaths = try? FileManager.default.subpathsOfDirectory(atPath: root.path) else {
            isReady = false
            rootName = root.lastPathComponent
            rows = []
            status = "\(root.path) がありません"
            return
        }
        var files: [String] = []
        var directories: [String] = []
        for subpath in subpaths where NoteTree.isVisible(subpath) {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root.appendingPathComponent(subpath).path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                directories.append(subpath)
            } else {
                files.append(subpath)
            }
        }
        isReady = true
        rootName = root.lastPathComponent
        rows = NoteTree.rows(files: files + dirty.filter { !files.contains($0) }, directories: directories, expanded: expanded)
    }

    private func mark(_ path: String, isDirty: Bool) {
        guard dirty.contains(path) != isDirty else { return }
        if isDirty {
            dirty.insert(path)
        } else {
            dirty.remove(path)
        }
    }

    private func url(for path: String) -> URL? {
        root?.appendingPathComponent(path)
    }

    private func read(_ path: String) -> String? {
        guard let url = url(for: path), let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url, options: .atomic)
    }
}

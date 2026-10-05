import Foundation

public struct Note: Codable, Equatable, Sendable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct NoteSummary: Codable, Equatable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public enum NoteTitle {
    public static let untitled = "無題"
    private static let prefix = try? NSRegularExpression(
        pattern: "^(?:#{1,6}[ \\t]+|>[ \\t]?|[-*+][ \\t]+(?:\\[[ xX]\\][ \\t]+)?|\\d+[.)][ \\t]+)"
    )

    public static func make(from text: String) -> String {
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            let stripped = prefix?.stringByReplacingMatches(in: trimmed, range: range, withTemplate: "") ?? trimmed
            let title = stripped.trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                return title
            }
        }
        return untitled
    }
}

public actor NoteStore {
    private let directory: URL
    private let usesTrash: Bool
    private let manager = FileManager.default

    public init(directory: URL, usesTrash: Bool = true) {
        self.directory = directory
        self.usesTrash = usesTrash
    }

    public func list() -> [NoteSummary] {
        let names = (try? manager.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasSuffix(".md") && !$0.hasPrefix(".") }
            .map { String($0.dropLast(3)) }
            .sorted()
            .compactMap { id in
                read(id).map { NoteSummary(id: id, title: NoteTitle.make(from: $0.text)) }
            }
    }

    public func read(_ id: String) -> Note? {
        guard let url = url(for: id), let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return Note(id: id, text: text)
    }

    public func create(at date: Date = Date()) throws -> Note {
        let note = Note(id: UUIDv7.make(at: date), text: "")
        try write(note)
        return note
    }

    public func write(_ note: Note) throws {
        guard let url = url(for: note.id) else { throw CocoaError(.fileWriteInvalidFileName) }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(note.text.utf8).write(to: url, options: .atomic)
    }

    public func delete(_ id: String) throws {
        guard let url = url(for: id), manager.fileExists(atPath: url.path) else { return }
        if usesTrash {
            try manager.trashItem(at: url, resultingItemURL: nil)
        } else {
            try manager.removeItem(at: url)
        }
    }

    @discardableResult
    public func removeIfEmpty(_ id: String) throws -> Bool {
        guard let url = url(for: id), let note = read(id) else { return false }
        guard note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        try manager.removeItem(at: url)
        return true
    }

    private func url(for id: String) -> URL? {
        guard !id.isEmpty, !id.hasPrefix("."), !id.contains("/") else { return nil }
        return directory.appendingPathComponent(id + ".md")
    }
}

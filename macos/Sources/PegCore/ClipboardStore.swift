import Foundation

public struct ClipEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let text: String
    public let copiedAt: Date

    public init(id: UUID = UUID(), text: String, copiedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
    }

    public var preview: String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

public struct ClipboardStore {
    public private(set) var entries: [ClipEntry]
    public let limit: Int

    public init(entries: [ClipEntry] = [], limit: Int = 100) {
        self.limit = limit
        self.entries = Array(entries.prefix(limit))
    }

    public mutating func add(_ text: String, at date: Date = Date()) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        entries.removeAll { $0.text == text }
        entries.insert(ClipEntry(text: text, copiedAt: date), at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    public static func load(from url: URL, limit: Int = 100) -> ClipboardStore {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url), let entries = try? decoder.decode([ClipEntry].self, from: data) else {
            return ClipboardStore(limit: limit)
        }
        return ClipboardStore(entries: entries, limit: limit)
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

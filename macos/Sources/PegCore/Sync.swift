import Foundation

public struct SyncEntry: Codable, Equatable, Sendable {
    public var etag: String
    public var hash: String

    public init(etag: String, hash: String) {
        self.etag = etag
        self.hash = hash
    }
}

public struct SyncState: Codable, Equatable, Sendable {
    public var version: Int
    public var scope: String?
    public var entries: [String: SyncEntry]

    public init(version: Int = 1, scope: String? = nil, entries: [String: SyncEntry] = [:]) {
        self.version = version
        self.scope = scope
        self.entries = entries
    }

    public static func load(from url: URL) -> SyncState {
        guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            return SyncState()
        }
        return state
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

public struct SyncAction: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case put
        case get
        case trashLocal
        case deleteRemote
        case keepAsConflict
        case conflict
        case dropState
    }

    public let type: Kind
    public let path: String
    public let ifMatch: String?

    public init(type: Kind, path: String, ifMatch: String? = nil) {
        self.type = type
        self.path = path
        self.ifMatch = ifMatch
    }
}

public enum SyncPlanner {
    public static func plan(remote: [String: String], local: [String: String], state: [String: SyncEntry]) -> [SyncAction] {
        let paths = Set(remote.keys).union(local.keys).union(state.keys).sorted()
        return paths.compactMap { path in
            guard let type = kind(remote: remote[path], local: local[path], state: state[path]) else { return nil }
            if type == .put, remote[path] != nil {
                return SyncAction(type: type, path: path, ifMatch: state[path]?.etag)
            }
            return SyncAction(type: type, path: path)
        }
    }

    public static func isBlocked(remoteCount: Int, localCount: Int, stateCount: Int, trashCount: Int, deleteCount: Int) -> Bool {
        if stateCount > 0, remoteCount == 0 || localCount == 0 {
            return true
        }
        let removed = max(trashCount, deleteCount)
        return removed >= 10 && removed * 2 > stateCount
    }

    static func kind(remote: String?, local: String?, state: SyncEntry?) -> SyncAction.Kind? {
        switch (local, remote, state) {
        case (nil, nil, nil):
            return nil
        case (nil, nil, .some):
            return .dropState
        case (.some, nil, nil):
            return .put
        case let (.some(hash), nil, .some(entry)):
            return hash == entry.hash ? .trashLocal : .keepAsConflict
        case (nil, .some, nil):
            return .get
        case let (nil, .some(etag), .some(entry)):
            return etag == entry.etag ? .deleteRemote : .get
        case (.some, .some, nil):
            return .conflict
        case let (.some(hash), .some(etag), .some(entry)):
            switch (hash != entry.hash, etag != entry.etag) {
            case (false, false):
                return nil
            case (true, false):
                return .put
            case (false, true):
                return .get
            case (true, true):
                return .conflict
            }
        }
    }
}

public enum SyncFilter {
    static let pluginDirectory = ".obsidian/plugins/peg-sync/"

    public static func includes(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        if name == ".DS_Store" || name.hasPrefix("._") {
            return false
        }
        if path.hasPrefix(".trash/") {
            return false
        }
        if path.hasPrefix(".obsidian/") {
            return path.hasPrefix(pluginDirectory) && path != pluginDirectory + "data.json"
        }
        return true
    }
}

public enum SyncPath {
    public static func key(for path: String, prefix: String) -> String {
        prefix + path.precomposedStringWithCanonicalMapping
    }

    public static func path(for key: String, prefix: String) -> String? {
        let normalized = key.precomposedStringWithCanonicalMapping
        guard normalized.hasPrefix(prefix) else { return nil }
        let path = String(normalized.dropFirst(prefix.count))
        guard !path.isEmpty, !path.hasSuffix("/") else { return nil }
        return path
    }
}

public enum ConflictName {
    public static func make(path: String, device: String, stamp: String) -> String {
        let directory: String
        let name: String
        if let slash = path.lastIndex(of: "/") {
            directory = String(path[...slash])
            name = String(path[path.index(after: slash)...])
        } else {
            directory = ""
            name = path
        }
        let suffix = ".conflict-" + sanitized(device) + "-" + stamp
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return directory + name + suffix
        }
        return directory + String(name[..<dot]) + suffix + String(name[dot...])
    }

    public static func stamp(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "%04d%02d%02d-%02d%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0,
            parts.hour ?? 0,
            parts.minute ?? 0
        )
    }

    static func sanitized(_ device: String) -> String {
        let cleaned = String(device.map { character in
            let allowed = character.isASCII && (character.isLetter || character.isNumber || character == "-" || character == "_")
            return allowed ? character : "-"
        })
        return cleaned.isEmpty ? "device" : cleaned
    }
}

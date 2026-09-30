import Foundation

public struct NoteRow: Identifiable, Equatable, Sendable {
    public let path: String
    public let name: String
    public let depth: Int
    public let isDirectory: Bool
    public let isExpanded: Bool

    public init(path: String, name: String, depth: Int, isDirectory: Bool, isExpanded: Bool) {
        self.path = path
        self.name = name
        self.depth = depth
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
    }

    public var id: String {
        path
    }
}

public enum NoteTree {
    struct Node {
        let path: String
        let name: String
        let isDirectory: Bool
    }

    public static func isVisible(_ path: String) -> Bool {
        !path.split(separator: "/").contains { $0.hasPrefix(".") }
    }

    public static func parent(of path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return String(path[..<slash])
    }

    public static func ancestors(of path: String) -> [String] {
        var result: [String] = []
        var current = parent(of: path)
        while !current.isEmpty {
            result.append(current)
            current = parent(of: current)
        }
        return result
    }

    public static func rows(files: [String], directories: [String], expanded: Set<String>) -> [NoteRow] {
        var allDirectories = Set(directories.filter { !$0.isEmpty })
        for path in directories + files {
            allDirectories.formUnion(ancestors(of: path))
        }
        var children: [String: [Node]] = [:]
        for path in allDirectories {
            children[parent(of: path), default: []].append(Node(path: path, name: name(of: path), isDirectory: true))
        }
        for path in Set(files).subtracting(allDirectories) {
            children[parent(of: path), default: []].append(Node(path: path, name: name(of: path), isDirectory: false))
        }
        return rows(in: "", depth: 0, children: children, expanded: expanded)
    }

    static func rows(in directory: String, depth: Int, children: [String: [Node]], expanded: Set<String>) -> [NoteRow] {
        let nodes = (children[directory] ?? []).sorted { left, right in
            if left.isDirectory != right.isDirectory {
                return left.isDirectory
            }
            let order = left.name.compare(right.name, options: [.caseInsensitive, .numeric])
            return order == .orderedSame ? left.name < right.name : order == .orderedAscending
        }
        var result: [NoteRow] = []
        for node in nodes {
            let isExpanded = node.isDirectory && expanded.contains(node.path)
            result.append(NoteRow(path: node.path, name: node.name, depth: depth, isDirectory: node.isDirectory, isExpanded: isExpanded))
            if isExpanded {
                result += rows(in: node.path, depth: depth + 1, children: children, expanded: expanded)
            }
        }
        return result
    }

    static func name(of path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return path }
        return String(path[path.index(after: slash)...])
    }
}

public enum NoteName {
    public static func path(for input: String, in directory: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        var parts = trimmed.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.contains(where: { $0.isEmpty || $0.hasPrefix(".") || $0.contains(":") }) else { return nil }
        if let last = parts.last, !last.contains(".") {
            parts[parts.count - 1] = last + ".md"
        }
        let relative = parts.joined(separator: "/")
        return directory.isEmpty ? relative : directory + "/" + relative
    }
}

public enum NoteSave: Equatable, Sendable {
    case unchanged
    case write
    case conflict

    public static func decide(base: String?, disk: String?, text: String) -> NoteSave {
        if disk == text {
            return .unchanged
        }
        if disk == nil || disk == base {
            return .write
        }
        return .conflict
    }
}

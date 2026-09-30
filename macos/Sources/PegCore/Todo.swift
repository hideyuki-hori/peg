import Foundation

public struct TodoItem: Identifiable, Hashable, Sendable {
    public let raw: String
    public let occurrence: Int
    public let title: String
    public let isDone: Bool
    public let due: String?

    public init(raw: String, occurrence: Int, title: String, isDone: Bool, due: String?) {
        self.raw = raw
        self.occurrence = occurrence
        self.title = title
        self.isDone = isDone
        self.due = due
    }

    public var id: String {
        "\(occurrence):\(raw)"
    }

    public var dueText: String? {
        guard let due, due.count == 10 else { return nil }
        return due.dropFirst(5).replacingOccurrences(of: "-", with: "/")
    }

    public func isOverdue(today: String) -> Bool {
        guard let due, !isDone else { return false }
        return due < today
    }
}

public enum TodoDocument {
    static let dueMark: Character = "📅"

    public static func parse(_ text: String) -> [TodoItem] {
        var counts: [String: Int] = [:]
        var items: [TodoItem] = []
        for line in lines(of: text) {
            guard let task = Task(line: line) else { continue }
            let occurrence = counts[line, default: 0]
            counts[line] = occurrence + 1
            let content = split(task.body)
            guard !content.title.isEmpty else { continue }
            items.append(TodoItem(
                raw: line,
                occurrence: occurrence,
                title: content.title,
                isDone: task.isDone,
                due: content.due
            ))
        }
        return items
    }

    public static func sorted(_ items: [TodoItem]) -> [TodoItem] {
        items.filter { !$0.isDone } + items.filter(\.isDone)
    }

    public static func toggle(_ item: TodoItem, in text: String) -> String? {
        replace(item, in: text) { line in
            guard let task = Task(line: line) else { return line }
            return task.prefix + "[" + (task.isDone ? " " : "x") + "] " + task.body
        }
    }

    public static func remove(_ item: TodoItem, in text: String) -> String? {
        replace(item, in: text) { _ in nil }
    }

    public static func add(_ input: String, to text: String, today: Date, calendar: Calendar = .current) -> String? {
        let cleaned = input
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        var title = cleaned
        var due: String?
        if let range = cleaned.range(of: " @", options: .backwards) {
            let token = String(cleaned[range.upperBound...])
            if let parsed = dueDate(from: token, today: today, calendar: calendar) {
                due = parsed
                title = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        guard !title.isEmpty else { return nil }
        var line = "- [ ] " + title
        if let due {
            line += " \(dueMark) " + due
        }
        if text.isEmpty {
            return line + "\n"
        }
        return text + (text.hasSuffix("\n") ? "" : "\n") + line + "\n"
    }

    public static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func dueDate(from token: String, today: Date, calendar: Calendar) -> String? {
        let numbers = token.split(whereSeparator: { $0 == "/" || $0 == "-" }).map { Int($0) }
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 != nil }) else { return nil }
        let values = numbers.compactMap { $0 }
        var parts = DateComponents()
        switch values.count {
        case 2:
            parts.year = calendar.component(.year, from: today)
            parts.month = values[0]
            parts.day = values[1]
        case 3:
            parts.year = values[0]
            parts.month = values[1]
            parts.day = values[2]
        default:
            return nil
        }
        guard var date = validDate(parts, calendar: calendar) else { return nil }
        if values.count == 2, date < calendar.startOfDay(for: today) {
            parts.year = (parts.year ?? 0) + 1
            guard let next = validDate(parts, calendar: calendar) else { return nil }
            date = next
        }
        return dayString(date, calendar: calendar)
    }

    static func validDate(_ parts: DateComponents, calendar: Calendar) -> Date? {
        guard let date = calendar.date(from: parts) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == parts.year, resolved.month == parts.month, resolved.day == parts.day else { return nil }
        return date
    }

    static func split(_ body: String) -> (title: String, due: String?) {
        guard let mark = body.firstIndex(of: dueMark) else {
            return (body.trimmingCharacters(in: .whitespaces), nil)
        }
        let after = body[body.index(after: mark)...].drop { $0 == " " }
        let candidate = String(after.prefix(10))
        guard isDay(candidate) else {
            return (body.trimmingCharacters(in: .whitespaces), nil)
        }
        let rest = String(after.dropFirst(10))
        let title = (String(body[..<mark]).trimmingCharacters(in: .whitespaces) + " " + rest.trimmingCharacters(in: .whitespaces))
            .trimmingCharacters(in: .whitespaces)
        return (title, candidate)
    }

    static func isDay(_ text: String) -> Bool {
        let characters = Array(text)
        guard characters.count == 10 else { return false }
        for (index, character) in characters.enumerated() {
            if index == 4 || index == 7 {
                guard character == "-" else { return false }
            } else {
                guard character.isASCII, character.isNumber else { return false }
            }
        }
        return true
    }

    static func lines(of text: String) -> [String] {
        text.components(separatedBy: "\n")
    }

    static func replace(_ item: TodoItem, in text: String, with transform: (String) -> String?) -> String? {
        var all = lines(of: text)
        let matches = all.indices.filter { all[$0] == item.raw }
        guard !matches.isEmpty else { return nil }
        let index = matches.indices.contains(item.occurrence) ? matches[item.occurrence] : matches[0]
        if let replacement = transform(all[index]) {
            all[index] = replacement
        } else {
            all.remove(at: index)
        }
        return all.joined(separator: "\n")
    }

    struct Task {
        let prefix: String
        let isDone: Bool
        let body: String

        init?(line: String) {
            let indent = line.prefix { $0 == " " || $0 == "\t" }
            let rest = line.dropFirst(indent.count)
            guard let bullet = rest.first, bullet == "-" || bullet == "*" else { return nil }
            let marker = Array(rest.dropFirst().prefix(5))
            guard marker.count == 5, marker[0] == " ", marker[1] == "[", marker[3] == "]", marker[4] == " " else { return nil }
            switch marker[2] {
            case " ":
                isDone = false
            case "x", "X":
                isDone = true
            default:
                return nil
            }
            prefix = String(indent) + String(bullet) + " "
            body = String(rest.dropFirst(6))
        }
    }
}

public struct R2Config: Codable, Equatable, Sendable {
    public var accountId: String
    public var bucket: String
    public var prefix: String?
    public var accessKeyId: String
    public var secretAccessKey: String

    public init(accountId: String, bucket: String, prefix: String? = nil, accessKeyId: String, secretAccessKey: String) {
        self.accountId = accountId
        self.bucket = bucket
        self.prefix = prefix
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
}

public struct SyncConfig: Codable, Equatable, Sendable {
    public var deviceName: String?

    public init(deviceName: String? = nil) {
        self.deviceName = deviceName
    }
}

public struct EditorConfig: Codable, Equatable, Sendable {
    public var root: String?

    public init(root: String? = nil) {
        self.root = root
    }
}

public struct PegConfig: Codable, Equatable, Sendable {
    public var vaultPath: String?
    public var r2: R2Config?
    public var sync: SyncConfig?
    public var editor: EditorConfig?

    public init(vaultPath: String? = nil, r2: R2Config? = nil, sync: SyncConfig? = nil, editor: EditorConfig? = nil) {
        self.vaultPath = vaultPath
        self.r2 = r2
        self.sync = sync
        self.editor = editor
    }

    public static func load(from url: URL) -> PegConfig {
        guard let data = try? Data(contentsOf: url), let config = try? JSONDecoder().decode(PegConfig.self, from: data) else {
            return PegConfig()
        }
        return config
    }

    public func todoFile(homeDirectory: String = NSHomeDirectory()) -> URL? {
        vaultDirectory(homeDirectory: homeDirectory)?
            .appendingPathComponent("peg")
            .appendingPathComponent("todo.md")
    }

    public func vaultDirectory(homeDirectory: String = NSHomeDirectory()) -> URL? {
        PegConfig.expand(vaultPath, homeDirectory: homeDirectory)
    }

    public func editorRoot(homeDirectory: String = NSHomeDirectory()) -> URL? {
        PegConfig.expand(editor?.root, homeDirectory: homeDirectory) ?? vaultDirectory(homeDirectory: homeDirectory)
    }

    static func expand(_ path: String?, homeDirectory: String) -> URL? {
        guard let path = path?.trimmingCharacters(in: .whitespaces), !path.isEmpty else { return nil }
        var expanded = path
        if expanded == "~" {
            expanded = homeDirectory
        } else if expanded.hasPrefix("~/") {
            expanded = homeDirectory + String(expanded.dropFirst())
        }
        guard expanded.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: expanded)
    }
}

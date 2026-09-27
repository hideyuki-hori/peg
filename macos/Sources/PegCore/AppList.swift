import Foundation

public struct AppEntry: Identifiable, Hashable, Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var id: String {
        url.path
    }

    public var name: String {
        url.deletingPathExtension().lastPathComponent
    }
}

public enum AppList {
    public static func parse(_ text: String, homeDirectory: String = NSHomeDirectory()) -> [AppEntry] {
        var seen = Set<String>()
        var entries: [AppEntry] = []
        for line in text.components(separatedBy: .newlines) {
            guard let path = normalize(line, homeDirectory: homeDirectory) else { continue }
            guard seen.insert(path).inserted else { continue }
            entries.append(AppEntry(url: URL(fileURLWithPath: path)))
        }
        return entries
    }

    public static func load(from url: URL) -> [AppEntry] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }

    static func normalize(_ line: String, homeDirectory: String) -> String? {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        } else {
            value = unescape(value)
        }
        if value == "~" {
            value = homeDirectory
        } else if value.hasPrefix("~/") {
            value = homeDirectory + String(value.dropFirst())
        }
        while value.count > 1, value.hasSuffix("/") {
            value = String(value.dropLast())
        }
        guard value.hasPrefix("/") else { return nil }
        return value
    }

    static func unescape(_ line: String) -> String {
        var result = ""
        var escaping = false
        for character in line {
            if escaping {
                result.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}

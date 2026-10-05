import Foundation

public struct StyleSpan: Codable, Equatable, Sendable {
    public enum Kind: Codable, Equatable, Sendable {
        case heading(Int)
        case marker
        case bold
        case italic
        case code
        case codeBlock
        case quote
        case listMarker
        case checkbox(Bool)
        case done
    }

    public let location: Int
    public let length: Int
    public let kind: Kind

    public init(location: Int, length: Int, kind: Kind) {
        self.location = location
        self.length = length
        self.kind = kind
    }
}

public enum MarkdownStyler {
    private static let fence = regex("^```[^\\n]*\\n(?:[\\s\\S]*?\\n)?```[ \\t]*$|^```[^\\n]*(?:\\n[\\s\\S]*)?\\z")
    private static let fenceLine = regex("^```[^\\n]*$")
    private static let heading = regex("^(#{1,6})([ \\t]+)(.*)$")
    private static let quote = regex("^(>[ \\t]?)(.*)$")
    private static let bullet = regex("^[ \\t]*([-*+])[ \\t]+")
    private static let ordered = regex("^[ \\t]*(\\d+[.)])[ \\t]+")
    private static let unchecked = regex("^[ \\t]*[-*+][ \\t]+(\\[ \\])(?=[ \\t]|$)")
    private static let checked = regex("^[ \\t]*[-*+][ \\t]+(\\[[xX]\\])(?:[ \\t]+(.*))?$")
    private static let code = regex("`[^`\\n]+`")
    private static let bold = regex("(\\*\\*|__)(?=\\S)([^\\n]+?)(?<=\\S)\\1")
    private static let italics = [
        regex("(?<![*\\w])\\*(?=[^\\s*])([^*\\n]+?)(?<=[^\\s*])\\*(?![*\\w])"),
        regex("(?<![_\\w])_(?=[^\\s_])([^_\\n]+?)(?<=[^\\s_])_(?![_\\w])")
    ]

    public static func spans(in text: String) -> [StyleSpan] {
        var spans: [StyleSpan] = []
        func add(_ range: NSRange, _ kind: StyleSpan.Kind) {
            guard range.location != NSNotFound, range.length > 0 else { return }
            spans.append(StyleSpan(location: range.location, length: range.length, kind: kind))
        }
        func edges(of range: NSRange, width: Int) {
            add(NSRange(location: range.location, length: width), .marker)
            add(NSRange(location: NSMaxRange(range) - width, length: width), .marker)
        }

        let blocks = matches(fence, in: text).map(\.range)
        func isFree(_ range: NSRange, from taken: [NSRange]) -> Bool {
            !taken.contains { NSIntersectionRange($0, range).length > 0 }
        }
        for block in blocks {
            add(block, .codeBlock)
        }
        for match in matches(fenceLine, in: text) where !isFree(match.range, from: blocks) {
            add(match.range, .marker)
        }
        for match in matches(heading, in: text) where isFree(match.range, from: blocks) {
            add(match.range, .heading(match.range(at: 1).length))
            add(NSUnionRange(match.range(at: 1), match.range(at: 2)), .marker)
        }
        for match in matches(quote, in: text) where isFree(match.range, from: blocks) {
            add(match.range(at: 2), .quote)
            add(match.range(at: 1), .marker)
        }
        for pattern in [bullet, ordered] {
            for match in matches(pattern, in: text) where isFree(match.range, from: blocks) {
                add(match.range(at: 1), .listMarker)
            }
        }
        for match in matches(unchecked, in: text) where isFree(match.range, from: blocks) {
            add(match.range(at: 1), .checkbox(false))
        }
        for match in matches(checked, in: text) where isFree(match.range, from: blocks) {
            add(match.range(at: 1), .checkbox(true))
            add(match.range(at: 2), .done)
        }

        let codes = matches(code, in: text).map(\.range).filter { isFree($0, from: blocks) }
        for range in codes {
            add(range, .code)
            edges(of: range, width: 1)
        }
        let taken = blocks + codes
        for match in matches(bold, in: text) where isFree(match.range, from: taken) {
            add(match.range(at: 2), .bold)
            edges(of: match.range, width: 2)
        }
        for pattern in italics {
            for match in matches(pattern, in: text) where isFree(match.range, from: taken) {
                add(match.range(at: 1), .italic)
                edges(of: match.range, width: 1)
            }
        }
        return spans
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private static func matches(_ regex: NSRegularExpression?, in text: String) -> [NSTextCheckingResult] {
        regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    }
}

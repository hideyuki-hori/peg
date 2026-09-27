import Foundation

public enum MeetLink {
    static let pattern = "(?<![A-Za-z0-9.\\-])(?:https?://)?meet\\.google\\.com/[A-Za-z0-9][A-Za-z0-9_\\-/]*(?:\\?[A-Za-z0-9_\\-=&%.]*)?"

    public static func find(in texts: [String?]) -> URL? {
        for text in texts {
            guard let text, let url = find(in: text) else { continue }
            return url
        }
        return nil
    }

    public static func find(in text: String) -> URL? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = expression.firstMatch(in: text, options: [], range: whole),
            let range = Range(match.range, in: text)
        else { return nil }
        var value = String(text[range])
        while let last = value.last, "/?&.".contains(last) {
            value.removeLast()
        }
        let lowered = value.lowercased()
        if lowered.hasPrefix("http://") {
            value = "https://" + value.dropFirst("http://".count)
        } else if !lowered.hasPrefix("https://") {
            value = "https://" + value
        }
        return URL(string: value)
    }
}

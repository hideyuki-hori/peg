import Foundation

public enum Matcher {
    public static func score(query: String, candidate: String) -> Int? {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let haystack = candidate.lowercased()
        if needle.isEmpty {
            return 0
        }
        if haystack.hasPrefix(needle) {
            return 3
        }
        if haystack.contains(needle) {
            return 2
        }
        if isSubsequence(needle, of: haystack) {
            return 1
        }
        return nil
    }

    public static func filter<Item>(_ items: [Item], query: String, key: (Item) -> String) -> [Item] {
        var scored: [(index: Int, score: Int, item: Item)] = []
        for (index, item) in items.enumerated() {
            guard let score = score(query: query, candidate: key(item)) else { continue }
            scored.append((index, score, item))
        }
        scored.sort { left, right in
            if left.score != right.score {
                return left.score > right.score
            }
            return left.index < right.index
        }
        return scored.map(\.item)
    }

    static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var remaining = Substring(needle)
        for character in haystack {
            guard let next = remaining.first else { return true }
            if next == character {
                remaining = remaining.dropFirst()
            }
        }
        return remaining.isEmpty
    }
}

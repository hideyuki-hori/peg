import Foundation

public enum HintLabels {
    public static let homeRow: [Character] = Array("asdfghjkl")

    public enum Match: Equatable {
        case exact(Int)
        case partial
        case none
    }

    public static func make(count: Int, alphabet: [Character] = homeRow) -> [String] {
        guard count > 0, !alphabet.isEmpty else { return [] }
        let size = alphabet.count
        if count <= size {
            return alphabet.prefix(count).map { String($0) }
        }
        let singles = max(0, min(size - 1, (size * size - count) / (size - 1)))
        var labels = alphabet.prefix(singles).map { String($0) }
        for prefix in alphabet.dropFirst(singles) {
            for suffix in alphabet {
                guard labels.count < count else { return labels }
                labels.append(String(prefix) + String(suffix))
            }
        }
        return labels
    }

    public static func match(_ input: String, in labels: [String]) -> Match {
        guard !input.isEmpty else { return .partial }
        if let index = labels.firstIndex(of: input) {
            return .exact(index)
        }
        return labels.contains { $0.hasPrefix(input) } ? .partial : .none
    }
}

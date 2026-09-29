import Foundation

public struct Calculation: Equatable, Sendable {
    public let expression: String
    public let result: String

    public init(expression: String, result: String) {
        self.expression = expression
        self.result = result
    }
}

public enum Calculator {
    static let replacements: [Character: Character] = [
        "＋": "+", "－": "-", "ー": "-", "−": "-", "＊": "*", "×": "*", "／": "/", "÷": "/",
        "（": "(", "）": ")", "．": ".", "＾": "^",
        "０": "0", "１": "1", "２": "2", "３": "3", "４": "4",
        "５": "5", "６": "6", "７": "7", "８": "8", "９": "9"
    ]

    public static func calculate(_ input: String) -> Calculation? {
        let expression = input.trimmingCharacters(in: .whitespaces)
        guard let value = evaluate(expression) else { return nil }
        return Calculation(expression: expression, result: format(value))
    }

    public static func evaluate(_ input: String) -> Double? {
        var parser = Parser(normalize(input))
        guard let value = parser.parseExpression(), parser.isAtEnd, parser.operations > 0, value.isFinite else {
            return nil
        }
        return value
    }

    public static func format(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1e15 || (magnitude != 0 && magnitude < 1e-9) {
            return String(format: "%.10g", value)
        }
        let rounded = (value * 1e10).rounded() / 1e10
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded == 0 ? 0 : rounded)
        }
        var text = String(format: "%.10f", rounded)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        return text
    }

    static func normalize(_ input: String) -> [Character] {
        input.compactMap { character in
            if character == " " || character == "　" || character == "," || character == "，" {
                return nil
            }
            return replacements[character] ?? character
        }
    }

    struct Parser {
        private let characters: [Character]
        private var position = 0
        private(set) var operations = 0

        init(_ characters: [Character]) {
            self.characters = characters
        }

        var isAtEnd: Bool {
            position >= characters.count
        }

        mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while let symbol = peek(), symbol == "+" || symbol == "-" {
                position += 1
                guard let right = parseTerm() else { return nil }
                operations += 1
                value = symbol == "+" ? value + right : value - right
            }
            return value
        }

        private mutating func parseTerm() -> Double? {
            guard var value = parseUnary() else { return nil }
            while let symbol = peek(), symbol == "*" || symbol == "/" {
                position += 1
                guard let right = parseUnary() else { return nil }
                operations += 1
                if symbol == "*" {
                    value *= right
                } else {
                    guard right != 0 else { return nil }
                    value /= right
                }
            }
            return value
        }

        private mutating func parseUnary() -> Double? {
            if peek() == "-" {
                position += 1
                guard let value = parseUnary() else { return nil }
                return -value
            }
            if peek() == "+" {
                position += 1
                return parseUnary()
            }
            return parsePower()
        }

        private mutating func parsePower() -> Double? {
            guard let base = parsePrimary() else { return nil }
            guard peek() == "^" else { return base }
            position += 1
            guard let exponent = parseUnary() else { return nil }
            operations += 1
            return pow(base, exponent)
        }

        private mutating func parsePrimary() -> Double? {
            if peek() == "(" {
                position += 1
                guard let value = parseExpression(), peek() == ")" else { return nil }
                position += 1
                return value
            }
            return parseNumber()
        }

        private mutating func parseNumber() -> Double? {
            let start = position
            var digits = 0
            var points = 0
            while let character = peek() {
                if character.isASCII, character.isNumber {
                    digits += 1
                } else if character == "." {
                    points += 1
                } else {
                    break
                }
                position += 1
            }
            guard digits > 0, points <= 1 else { return nil }
            return Double(String(characters[start..<position]))
        }

        private func peek() -> Character? {
            characters.indices.contains(position) ? characters[position] : nil
        }
    }
}

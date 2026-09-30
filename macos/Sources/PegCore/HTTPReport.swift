import Foundation

public struct HTTPReport: Equatable, Sendable {
    public static let format = "%{http_code}\\n%{header_json}"

    public let status: Int
    public let headers: [String: [String]]

    public init(status: Int, headers: [String: [String]]) {
        self.status = status
        self.headers = headers
    }

    public static func parse(_ data: Data) -> HTTPReport? {
        guard let text = String(data: data, encoding: .utf8), let end = text.firstIndex(of: "\n") else { return nil }
        guard let status = Int(text[..<end]) else { return nil }
        let body = Data(text[text.index(after: end)...].utf8)
        guard let headers = try? JSONDecoder().decode([String: [String]].self, from: body) else { return nil }
        return HTTPReport(status: status, headers: headers)
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]?.first
    }
}

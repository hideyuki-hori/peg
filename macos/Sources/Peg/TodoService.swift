import Foundation
import PegCore

enum TodoService {
    enum Failure: Error {
        case unreadable
    }

    static func file() -> URL? {
        guard let url = PegConfig.load(from: PegPaths.configFile).todoFile() else { return nil }
        let vault = url.deletingLastPathComponent().deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: vault.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return url
    }

    static func read(_ url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw Failure.unreadable }
        return text
    }

    static func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url, options: .atomic)
    }
}

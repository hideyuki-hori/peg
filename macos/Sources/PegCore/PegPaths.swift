import Foundation

public enum PegPaths {
    public static var configDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config")
            .appendingPathComponent("peg")
    }

    public static var appsFile: URL {
        configDirectory.appendingPathComponent("apps.csv")
    }

    public static var configFile: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    public static var clipboardFile: URL {
        configDirectory.appendingPathComponent("clipboard.json")
    }

    public static var syncStateFile: URL {
        configDirectory.appendingPathComponent("sync-state.json")
    }

    public static func prepare() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        if !manager.fileExists(atPath: appsFile.path) {
            try Data().write(to: appsFile)
        }
    }
}

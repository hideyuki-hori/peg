import Foundation

public struct StickyPlacement: Codable, Equatable, Sendable {
    public let id: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(id: String, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct StickyState: Codable, Equatable, Sendable {
    public var placements: [StickyPlacement]
    public var focused: String?

    public init(placements: [StickyPlacement] = [], focused: String? = nil) {
        self.placements = placements
        self.focused = focused
    }
}

public actor StickyStateStore {
    private let file: URL

    public init(file: URL) {
        self.file = file
    }

    public func load() -> StickyState {
        guard let data = try? Data(contentsOf: file) else { return StickyState() }
        return (try? JSONDecoder().decode(StickyState.self, from: data)) ?? StickyState()
    }

    public func save(_ state: StickyState) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: file, options: .atomic)
    }
}

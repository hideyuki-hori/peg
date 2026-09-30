import XCTest
import PegCore
@testable import PegSync

final class R2LiveTests: XCTestCase {
    private func makeClient() throws -> R2Client {
        guard ProcessInfo.processInfo.environment["PEG_R2_LIVE"] == "1" else {
            throw XCTSkip("PEG_R2_LIVE is not set")
        }
        guard var config = PegConfig.load(from: PegPaths.configFile).r2 else {
            throw XCTSkip("r2 is not configured")
        }
        config.prefix = "peg-selftest/" + UUID().uuidString + "/"
        return R2Client(config: config)
    }

    private func failure(_ operation: () async throws -> Void) async -> String {
        do {
            try await operation()
            return "none"
        } catch R2Failure.preconditionFailed {
            return "preconditionFailed"
        } catch R2Failure.forbidden {
            return "forbidden"
        } catch let R2Failure.status(code) {
            return "status \(code)"
        } catch {
            return "other"
        }
    }

    func testRoundTripAndConditions() async throws {
        let client = try makeClient()
        let first = Data("first".utf8)
        let second = Data("second".utf8)
        let name = "メモ/か\u{3099} b+c.md"

        let empty = try await client.list()
        XCTAssertEqual(empty, [:])

        let etag1 = try await client.put("a.md", data: first, condition: .ifNoneMatch)
        let duplicate = await failure { _ = try await client.put("a.md", data: second, condition: .ifNoneMatch) }
        XCTAssertEqual(duplicate, "preconditionFailed")

        let fetched = try await client.get("a.md")
        XCTAssertEqual(fetched, R2Object(data: first, etag: etag1))

        let etag2 = try await client.put("a.md", data: second, condition: .ifMatch(etag1))
        XCTAssertNotEqual(etag1, etag2)
        let stale = await failure { _ = try await client.put("a.md", data: first, condition: .ifMatch(etag1)) }
        XCTAssertEqual(stale, "preconditionFailed")

        let etag3 = try await client.put(name, data: Data(), condition: .ifNoneMatch)
        let listed = try await client.list()
        XCTAssertEqual(listed, ["a.md": etag2, "メモ/が b+c.md": etag3])
        let emptyObject = try await client.get(name)
        XCTAssertEqual(emptyObject.data, Data())

        let missing = await failure { _ = try await client.get("missing.md") }
        XCTAssertEqual(missing, "status 404")

        try await client.delete("a.md")
        try await client.delete(name)
        try await client.delete("missing.md")
        let cleaned = try await client.list()
        XCTAssertEqual(cleaned, [:])
    }
}

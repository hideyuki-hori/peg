import XCTest
import PegCore
@testable import PegSync

private actor FakeRemote: RemoteStore {
    private var objects: [String: R2Object] = [:]
    private var counter = 0
    private var frozenList: [String: String]?

    func list() async throws -> [String: String] {
        frozenList ?? objects.mapValues(\.etag)
    }

    func get(_ path: String) async throws -> R2Object {
        guard let object = objects[path] else { throw R2Failure.status(404) }
        return object
    }

    func put(_ path: String, data: Data, condition: R2Condition) async throws -> String {
        switch condition {
        case .none:
            break
        case .ifNoneMatch:
            guard objects[path] == nil else { throw R2Failure.preconditionFailed }
        case let .ifMatch(etag):
            guard objects[path]?.etag == etag else { throw R2Failure.preconditionFailed }
        }
        counter += 1
        let etag = "etag\(counter)"
        objects[path] = R2Object(data: data, etag: etag)
        return etag
    }

    func delete(_ path: String) async throws {
        objects[path] = nil
    }

    func freezeList() {
        frozenList = objects.mapValues(\.etag)
    }

    func text(_ path: String) -> String? {
        objects[path].flatMap { String(data: $0.data, encoding: .utf8) }
    }

    func paths() -> [String] {
        objects.keys.sorted()
    }
}

private struct Device {
    let vault: URL
    let engine: SyncEngine
    let trashed: URL

    init(name: String, root: URL, remote: FakeRemote, folder: String = "vault") throws {
        vault = root.appendingPathComponent(name).appendingPathComponent(folder)
        let trashed = root.appendingPathComponent(name).appendingPathComponent("trashed")
        self.trashed = trashed
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trashed, withIntermediateDirectories: true)
        engine = SyncEngine(
            vault: vault,
            stateFile: root.appendingPathComponent(name).appendingPathComponent("sync-state.json"),
            remote: remote,
            device: name,
            scope: folder,
            trash: { url in
                try FileManager.default.moveItem(at: url, to: trashed.appendingPathComponent(url.lastPathComponent))
            },
            now: { Date(timeIntervalSince1970: 0) }
        )
    }

    func write(_ text: String, to path: String) throws {
        let url = vault.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func read(_ path: String) -> String? {
        try? String(contentsOf: vault.appendingPathComponent(path), encoding: .utf8)
    }

    func remove(_ path: String) throws {
        try FileManager.default.removeItem(at: vault.appendingPathComponent(path))
    }

    func files() throws -> [String] {
        try FileManager.default.subpathsOfDirectory(atPath: vault.path)
            .filter { !$0.hasSuffix("/") && read($0) != nil }
            .sorted()
    }
}

final class SyncEngineTests: XCTestCase {
    private var root = URL(fileURLWithPath: "/")
    private var remote = FakeRemote()
    private var stamp = ""

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("peg-sync-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        remote = FakeRemote()
        stamp = ConflictName.stamp(Date(timeIntervalSince1970: 0))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    private func device(_ name: String) throws -> Device {
        try Device(name: name, root: root, remote: remote)
    }

    func testUploadsThenDownloadsOnOtherDevice() async throws {
        let mac = try device("mac")
        let phone = try device("phone")
        try mac.write("hello", to: "notes/a.md")
        try mac.write("secret", to: ".obsidian/app.json")
        try mac.write("", to: ".DS_Store")

        let first = try await mac.engine.sync()
        XCTAssertEqual(first.uploaded, ["notes/a.md"])
        let second = try await phone.engine.sync()
        XCTAssertEqual(second.downloaded, ["notes/a.md"])
        XCTAssertEqual(phone.read("notes/a.md"), "hello")

        let again = try await mac.engine.sync()
        XCTAssertEqual(again, SyncReport())
    }

    func testPropagatesEditsAndDeletions() async throws {
        let mac = try device("mac")
        let phone = try device("phone")
        try mac.write("v1", to: "a.md")
        try mac.write("keep", to: "b.md")
        _ = try await mac.engine.sync()
        _ = try await phone.engine.sync()

        try phone.write("v2", to: "a.md")
        _ = try await phone.engine.sync()
        let pulled = try await mac.engine.sync()
        XCTAssertEqual(pulled.downloaded, ["a.md"])
        XCTAssertEqual(mac.read("a.md"), "v2")

        try mac.remove("a.md")
        let deleted = try await mac.engine.sync()
        XCTAssertEqual(deleted.deletedRemote, ["a.md"])
        let trashed = try await phone.engine.sync()
        XCTAssertEqual(trashed.trashed, ["a.md"])
        XCTAssertNil(phone.read("a.md"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: phone.trashed.appendingPathComponent("a.md").path))
        XCTAssertEqual(phone.read("b.md"), "keep")
    }

    func testKeepsLoserAsConflictFile() async throws {
        let mac = try device("mac")
        let phone = try device("phone")
        try mac.write("base", to: "notes/a.md")
        _ = try await mac.engine.sync()
        _ = try await phone.engine.sync()

        try phone.write("from phone", to: "notes/a.md")
        try mac.write("from mac", to: "notes/a.md")
        _ = try await phone.engine.sync()
        let report = try await mac.engine.sync()

        let conflictPath = "notes/a.conflict-mac-\(stamp).md"
        XCTAssertEqual(report.conflicts, [conflictPath])
        XCTAssertEqual(mac.read("notes/a.md"), "from phone")
        XCTAssertEqual(mac.read(conflictPath), "from mac")
        let remoteConflict = await remote.text(conflictPath)
        XCTAssertEqual(remoteConflict, "from mac")

        _ = try await phone.engine.sync()
        XCTAssertEqual(phone.read(conflictPath), "from mac")
        XCTAssertEqual(phone.read("notes/a.md"), "from phone")
        let settled = try await mac.engine.sync()
        XCTAssertEqual(settled, SyncReport())
    }

    func testIdenticalContentWithoutStateIsNotConflict() async throws {
        let mac = try device("mac")
        let phone = try device("phone")
        try mac.write("same", to: "a.md")
        try phone.write("same", to: "a.md")
        _ = try await mac.engine.sync()
        let report = try await phone.engine.sync()
        XCTAssertEqual(report, SyncReport())
        XCTAssertEqual(try phone.files(), ["a.md"])
        let settled = try await phone.engine.sync()
        XCTAssertEqual(settled, SyncReport())
    }

    func testEditWinsOverDeletion() async throws {
        let mac = try device("mac")
        let phone = try device("phone")
        try mac.write("base", to: "a.md")
        try mac.write("other", to: "b.md")
        _ = try await mac.engine.sync()
        _ = try await phone.engine.sync()

        try mac.remove("a.md")
        try phone.write("edited", to: "a.md")
        _ = try await phone.engine.sync()
        let revived = try await mac.engine.sync()
        XCTAssertEqual(revived.downloaded, ["a.md"])
        XCTAssertEqual(mac.read("a.md"), "edited")
    }

    func testEditedFileSurvivesRemoteDeletionAsConflict() async throws {
        let mac = try device("mac")
        let phone = try device("phone")
        try mac.write("base", to: "a.md")
        try mac.write("other", to: "b.md")
        _ = try await mac.engine.sync()
        _ = try await phone.engine.sync()

        try mac.remove("a.md")
        _ = try await mac.engine.sync()
        try phone.write("edited", to: "a.md")
        let report = try await phone.engine.sync()

        let conflictPath = "a.conflict-phone-\(stamp).md"
        XCTAssertEqual(report.conflicts, [conflictPath])
        XCTAssertNil(phone.read("a.md"))
        XCTAssertEqual(phone.read(conflictPath), "edited")
        let paths = await remote.paths()
        XCTAssertEqual(paths, [conflictPath, "b.md"])
    }

    func testRefusesToSyncWhenVaultLooksEmptied() async throws {
        let mac = try device("mac")
        try mac.write("a", to: "a.md")
        try mac.write("b", to: "b.md")
        _ = try await mac.engine.sync()

        try mac.remove("a.md")
        try mac.remove("b.md")
        do {
            _ = try await mac.engine.sync()
            XCTFail("sync should be blocked")
        } catch SyncFailure.blocked {
        }
        let paths = await remote.paths()
        XCTAssertEqual(paths, ["a.md", "b.md"])
    }

    func testRefusesToSyncWhenVaultIsMissing() async throws {
        let engine = SyncEngine(
            vault: root.appendingPathComponent("missing"),
            stateFile: root.appendingPathComponent("state.json"),
            remote: remote,
            device: "mac"
        )
        do {
            _ = try await engine.sync()
            XCTFail("sync should fail")
        } catch SyncFailure.vaultMissing {
        }
    }

    func testDoesNotOverwriteRemoteChangedAfterListing() async throws {
        let mac = try device("mac")
        let phone = try device("phone")
        try mac.write("base", to: "a.md")
        _ = try await mac.engine.sync()
        _ = try await phone.engine.sync()

        await remote.freezeList()
        try phone.write("from phone", to: "a.md")
        _ = try await phone.engine.sync()
        try mac.write("from mac", to: "a.md")
        let report = try await mac.engine.sync()

        XCTAssertEqual(report.deferred, ["a.md"])
        XCTAssertEqual(report.uploaded, [])
        let text = await remote.text("a.md")
        XCTAssertEqual(text, "from phone")
        XCTAssertEqual(mac.read("a.md"), "from mac")
    }

    func testForgetsStateWhenVaultChanges() async throws {
        let mac = try device("mac")
        try mac.write("a", to: "a.md")
        try mac.write("b", to: "b.md")
        _ = try await mac.engine.sync()

        let moved = try Device(name: "mac", root: root, remote: remote, folder: "other")
        try moved.write("c", to: "c.md")
        let report = try await moved.engine.sync()
        XCTAssertEqual(report.deletedRemote, [])
        XCTAssertEqual(report.uploaded, ["c.md"])
        XCTAssertEqual(report.downloaded, ["a.md", "b.md"])
        let paths = await remote.paths()
        XCTAssertEqual(paths, ["a.md", "b.md", "c.md"])
    }

    func testSummarizesReport() {
        var report = SyncReport()
        XCTAssertEqual(report.summary, "変更なし")
        XCTAssertFalse(report.needsAttention)
        report.uploaded = ["a.md", "b.md"]
        report.conflicts = ["a.conflict-mac-20260930-1405.md"]
        XCTAssertEqual(report.summary, "送信 2、競合 1")
        XCTAssertTrue(report.needsAttention)
    }

    func testStateFileIsPrivate() async throws {
        let mac = try device("mac")
        try mac.write("a", to: "a.md")
        _ = try await mac.engine.sync()
        let attributes = try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("mac/sync-state.json").path)
        XCTAssertEqual(attributes[.posixPermissions].map { "\($0)" }, "384")
    }

    func testRunsConcurrentCallsOneAtATime() async throws {
        let mac = try device("mac")
        for index in 0..<20 {
            try mac.write("note \(index)", to: "n\(index).md")
        }
        async let first = mac.engine.sync()
        async let second = mac.engine.sync()
        let reports = try await [first, second]
        XCTAssertEqual(reports.map(\.uploaded.count).sorted(), [0, 20])
        XCTAssertEqual(reports.flatMap(\.deferred), [])
    }
}

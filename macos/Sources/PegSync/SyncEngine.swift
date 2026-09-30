import Foundation
import PegCore

public struct SyncReport: Equatable, Sendable {
    public var uploaded: [String] = []
    public var downloaded: [String] = []
    public var trashed: [String] = []
    public var deletedRemote: [String] = []
    public var conflicts: [String] = []
    public var deferred: [String] = []
    public var failed: [String] = []

    public init() {}

    public var needsAttention: Bool {
        !conflicts.isEmpty || !failed.isEmpty
    }

    public var summary: String {
        let parts = [
            ("送信", uploaded.count + deletedRemote.count),
            ("受信", downloaded.count + trashed.count),
            ("競合", conflicts.count),
            ("保留", deferred.count),
            ("失敗", failed.count)
        ]
        let text = parts.filter { $0.1 > 0 }.map { "\($0.0) \($0.1)" }.joined(separator: "、")
        return text.isEmpty ? "変更なし" : text
    }
}

public enum SyncFailure: Error, Equatable {
    case vaultMissing
    case blocked
}

public actor SyncEngine {
    private enum Skip: Error {
        case changedDuringSync
    }

    private let vault: URL
    private let stateFile: URL
    private let remote: any RemoteStore
    private let device: String
    private let scope: String
    private let trash: @Sendable (URL) throws -> Void
    private let now: @Sendable () -> Date
    private var current: Task<SyncReport, Error>?

    public init(
        vault: URL,
        stateFile: URL,
        remote: any RemoteStore,
        device: String,
        scope: String = "",
        trash: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.vault = vault
        self.stateFile = stateFile
        self.remote = remote
        self.device = device
        self.scope = scope
        self.trash = trash
        self.now = now
    }

    public func sync() async throws -> SyncReport {
        let previous = current
        let task = Task {
            _ = try? await previous?.value
            return try await self.run()
        }
        current = task
        return try await task.value
    }

    private func run() async throws -> SyncReport {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: vault.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SyncFailure.vaultMissing
        }
        let remoteEntries = try await remote.list().filter { SyncFilter.includes($0.key) }
        let local = try scan()
        var state = SyncState.load(from: stateFile)
        if state.scope != scope {
            state = SyncState(scope: scope)
        }
        let actions = SyncPlanner.plan(remote: remoteEntries, local: local, state: state.entries)
        let blocked = SyncPlanner.isBlocked(
            remoteCount: remoteEntries.count,
            localCount: local.count,
            stateCount: state.entries.count,
            trashCount: actions.filter { $0.type == .trashLocal }.count,
            deleteCount: actions.filter { $0.type == .deleteRemote }.count
        )
        guard !blocked else { throw SyncFailure.blocked }

        var report = SyncReport()
        for action in actions {
            do {
                try await perform(action, scanned: local[action.path], state: &state, report: &report)
            } catch R2Failure.forbidden {
                throw R2Failure.forbidden
            } catch R2Failure.unreachable {
                throw R2Failure.unreachable
            } catch R2Failure.preconditionFailed {
                report.deferred.append(action.path)
            } catch Skip.changedDuringSync {
                report.deferred.append(action.path)
            } catch {
                report.failed.append(action.path)
            }
        }
        return report
    }

    private func perform(_ action: SyncAction, scanned: String?, state: inout SyncState, report: inout SyncReport) async throws {
        let path = action.path
        let url = fileURL(path)
        switch action.type {
        case .put:
            let data = try readUnchanged(url, scanned: scanned)
            let etag = try await remote.put(path, data: data, condition: action.ifMatch.map(R2Condition.ifMatch) ?? .ifNoneMatch)
            state.entries[path] = SyncEntry(etag: etag, hash: SigV4.sha256Hex(data))
            try save(state)
            report.uploaded.append(path)
        case .get:
            let object = try await remote.get(path)
            guard currentHash(url) == scanned else { throw Skip.changedDuringSync }
            try write(object.data, to: url)
            state.entries[path] = SyncEntry(etag: object.etag, hash: SigV4.sha256Hex(object.data))
            try save(state)
            report.downloaded.append(path)
        case .trashLocal:
            _ = try readUnchanged(url, scanned: scanned)
            try trash(url)
            state.entries[path] = nil
            try save(state)
            report.trashed.append(path)
        case .deleteRemote:
            try await remote.delete(path)
            state.entries[path] = nil
            try save(state)
            report.deletedRemote.append(path)
        case .keepAsConflict:
            let data = try readUnchanged(url, scanned: scanned)
            let conflictPath = try freeConflictPath(for: path)
            try FileManager.default.moveItem(at: url, to: fileURL(conflictPath))
            state.entries[path] = nil
            try save(state)
            report.conflicts.append(conflictPath)
            try await upload(conflictPath, data: data, state: &state)
        case .conflict:
            let object = try await remote.get(path)
            let data = try readUnchanged(url, scanned: scanned)
            if data == object.data {
                state.entries[path] = SyncEntry(etag: object.etag, hash: SigV4.sha256Hex(data))
                try save(state)
                return
            }
            let conflictPath = try freeConflictPath(for: path)
            try write(data, to: fileURL(conflictPath))
            try write(object.data, to: url)
            state.entries[path] = SyncEntry(etag: object.etag, hash: SigV4.sha256Hex(object.data))
            try save(state)
            report.conflicts.append(conflictPath)
            report.downloaded.append(path)
            try await upload(conflictPath, data: data, state: &state)
        case .dropState:
            state.entries[path] = nil
            try save(state)
        }
    }

    private func upload(_ path: String, data: Data, state: inout SyncState) async throws {
        let etag = try await remote.put(path, data: data, condition: .ifNoneMatch)
        state.entries[path] = SyncEntry(etag: etag, hash: SigV4.sha256Hex(data))
        try save(state)
    }

    private func scan() throws -> [String: String] {
        var result: [String: String] = [:]
        for subpath in try FileManager.default.subpathsOfDirectory(atPath: vault.path) {
            let path = subpath.precomposedStringWithCanonicalMapping
            guard SyncFilter.includes(path) else { continue }
            let url = vault.appendingPathComponent(subpath)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
            result[path] = SigV4.sha256Hex(try Data(contentsOf: url))
        }
        return result
    }

    private func fileURL(_ path: String) -> URL {
        vault.appendingPathComponent(path)
    }

    private func currentHash(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return SigV4.sha256Hex(data)
    }

    private func readUnchanged(_ url: URL, scanned: String?) throws -> Data {
        guard let data = try? Data(contentsOf: url), SigV4.sha256Hex(data) == scanned else {
            throw Skip.changedDuringSync
        }
        return data
    }

    private func freeConflictPath(for path: String) throws -> String {
        let conflictPath = ConflictName.make(path: path, device: device, stamp: ConflictName.stamp(now()))
        guard !FileManager.default.fileExists(atPath: fileURL(conflictPath).path) else {
            throw Skip.changedDuringSync
        }
        return conflictPath
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func save(_ state: SyncState) throws {
        try FileManager.default.createDirectory(at: stateFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try state.encoded().write(to: stateFile, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateFile.path)
    }
}

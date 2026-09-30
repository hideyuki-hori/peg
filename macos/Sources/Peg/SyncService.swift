import Foundation
import PegCore
import PegSync

struct SyncOutcome {
    let report: SyncReport?
    let message: String
    let succeeded: Bool

    var needsAttention: Bool {
        !succeeded || report?.needsAttention == true
    }

    var details: [String] {
        guard let report else { return [] }
        let groups = [
            ("送信", report.uploaded),
            ("受信", report.downloaded),
            ("ゴミ箱へ移動", report.trashed),
            ("R2 から削除", report.deletedRemote),
            ("競合", report.conflicts),
            ("保留", report.deferred),
            ("失敗", report.failed)
        ]
        return groups.flatMap { group in group.1.map { "\(group.0): \($0)" } }
    }
}

@MainActor
final class SyncService {
    static let shared = SyncService()

    private var engine: SyncEngine?
    private var engineConfig: PegConfig?

    func start() {
        Task {
            guard let outcome = await run() else { return }
            NSLog("Peg: sync: %@", outcome.message)
            if outcome.needsAttention {
                SyncService.notify(outcome.message)
            }
        }
    }

    func run() async -> SyncOutcome? {
        guard let engine = currentEngine() else { return nil }
        do {
            let report = try await engine.sync()
            return SyncOutcome(report: report, message: "同期しました（\(report.summary)）", succeeded: true)
        } catch SyncFailure.vaultMissing {
            return SyncOutcome(report: nil, message: "保管庫のフォルダがないため同期できません", succeeded: false)
        } catch SyncFailure.blocked {
            return SyncOutcome(report: nil, message: "削除されるファイルが多すぎるため同期を中止しました", succeeded: false)
        } catch R2Failure.forbidden {
            return SyncOutcome(report: nil, message: "R2 の認証に失敗しました", succeeded: false)
        } catch R2Failure.unreachable {
            return SyncOutcome(report: nil, message: "R2 に接続できませんでした", succeeded: false)
        } catch {
            return SyncOutcome(report: nil, message: "同期に失敗しました", succeeded: false)
        }
    }

    private func currentEngine() -> SyncEngine? {
        let config = PegConfig.load(from: PegPaths.configFile)
        if let engine, engineConfig == config {
            return engine
        }
        guard let r2 = config.r2, let vault = config.vaultDirectory() else {
            engine = nil
            engineConfig = nil
            return nil
        }
        let created = SyncEngine(
            vault: vault,
            stateFile: PegPaths.syncStateFile,
            remote: R2Client(config: r2),
            device: config.sync?.deviceName ?? "mac",
            scope: [r2.accountId, r2.bucket, r2.prefix ?? "", vault.path].joined(separator: "\n")
        )
        engine = created
        engineConfig = config
        return created
    }

    private static func notify(_ message: String) {
        _ = Shell.run("/usr/bin/osascript", [
            "-e", "on run argv",
            "-e", "display notification (item 1 of argv) with title \"Peg\"",
            "-e", "end run",
            message
        ])
    }
}

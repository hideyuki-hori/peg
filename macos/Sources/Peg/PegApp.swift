import AppKit

@main
enum PegApp {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--sync") {
            Task { @MainActor in
                guard let outcome = await SyncService.shared.run() else {
                    print("config.json に r2 と vaultPath がありません")
                    exit(1)
                }
                print(outcome.message)
                for line in outcome.details {
                    print(line)
                }
                exit(outcome.succeeded ? 0 : 1)
            }
            dispatchMain()
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

import AppKit
import PegCore

@MainActor
final class StatusItemController: NSObject {
    private let item: NSStatusItem
    private let worker = DispatchQueue(label: "app.peg.status-item", qos: .utility)
    private let onClick: (NSView) -> Void
    private var timer: Timer?
    private var ticks = 0
    private var batteryPercent: Int?
    private var isCharging = false

    init(onClick: @escaping (NSView) -> Void) {
        self.onClick = onClick
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = item.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.target = self
            button.action = #selector(clicked)
            button.setAccessibilityLabel("Peg")
        }
    }

    func start() {
        render()
        refreshBattery()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        ticks += 1
        if ticks % 30 == 0 {
            refreshBattery()
        }
        render()
    }

    private func render() {
        item.button?.title = ClockFormat.menuBar(Date(), batteryPercent: batteryPercent, isCharging: isCharging)
    }

    private func refreshBattery() {
        worker.async { [weak self] in
            let report = BatteryService.load()
            DispatchQueue.main.async {
                self?.batteryPercent = report?.percent
                self?.isCharging = report?.state == .charging
                self?.render()
            }
        }
    }

    @objc private func clicked() {
        guard let button = item.button else { return }
        onClick(button)
    }
}

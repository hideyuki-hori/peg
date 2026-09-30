import AppKit
import PegCore
import SwiftUI

@MainActor
final class ControlPanelModel: ObservableObject {
    @Published var now = Date()
    @Published var displayedMonth = Date()
    @Published var calendarAccess: AccessState = .needsAccess
    @Published var locationAccess: AccessState = .needsAccess
    @Published var agenda = Agenda()
    @Published var selectedDay: Date?
    @Published var selectedEvents: [AgendaEvent] = []
    @Published var markedDays: Set<Date> = []
    @Published var calendarColors: [String: Color] = [:]
    @Published var battery: BatteryReport?
    @Published var wifi = WiFiState()
    @Published var wifiMessage: String?
    @Published var joiningNetwork: String?
    @Published var bluetooth: BluetoothReport?
    @Published var bluetoothMessage: String?
    @Published var busyDevices: Set<String> = []
    @Published var isTodoReady = false
    @Published var todos: [TodoItem] = []
    @Published var todoMessage: String?

    var onClose: () -> Void = {}

    private var calendar: CalendarService?
    private var location: LocationAccess?
    private let wifiService = WiFiService()
    private let worker = DispatchQueue(label: "app.peg.control-panel", qos: .userInitiated)
    private let scanner = DispatchQueue(label: "app.peg.control-panel.wifi", qos: .utility)
    private var timer: Timer?
    private var ticks = 0
    private var isScanning = false
    private var events: [AgendaEvent] = []

    var todoToday: String {
        TodoDocument.dayString(now)
    }

    var grid: MonthGrid {
        MonthGrid(containing: displayedMonth, today: now)
    }

    func start() {
        prepareServices()
        now = Date()
        displayedMonth = now
        selectedDay = nil
        ticks = 0
        wifiMessage = nil
        bluetoothMessage = nil
        todoMessage = nil
        refreshTodos()
        refreshAccess()
        refreshCalendar()
        refreshStatus()
        refreshWiFi(scan: true)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func showPreviousMonth() {
        displayedMonth = MonthGrid.shift(displayedMonth, months: -1)
        refreshCalendar()
    }

    func showNextMonth() {
        displayedMonth = MonthGrid.shift(displayedMonth, months: 1)
        refreshCalendar()
    }

    func showCurrentMonth() {
        displayedMonth = now
        selectedDay = nil
        refreshCalendar()
    }

    func select(_ day: MonthDay) {
        selectedDay = day.isToday ? nil : Calendar.current.startOfDay(for: day.date)
        if day.isInMonth {
            rebuildAgenda()
        } else {
            displayedMonth = day.date
            refreshCalendar()
        }
    }

    func isSelected(_ day: MonthDay) -> Bool {
        guard let selectedDay else { return false }
        return Calendar.current.isDate(day.date, inSameDayAs: selectedDay)
    }

    func requestCalendarAccess() {
        switch calendarAccess {
        case .needsAccess:
            calendar?.request()
        case .denied:
            SystemSettings.calendarPrivacy.open()
            onClose()
        case .granted:
            break
        }
    }

    func requestLocationAccess() {
        switch locationAccess {
        case .needsAccess:
            location?.request()
        case .denied:
            SystemSettings.locationPrivacy.open()
            onClose()
        case .granted:
            break
        }
    }

    func openMeet(_ url: URL) {
        NSWorkspace.shared.open(url)
        onClose()
    }

    @discardableResult
    func addTodo(_ input: String) -> Bool {
        let today = now
        return updateTodos { TodoDocument.add(input, to: $0, today: today) }
    }

    func toggle(_ item: TodoItem) {
        updateTodos { TodoDocument.toggle(item, in: $0) }
    }

    func remove(_ item: TodoItem) {
        updateTodos { TodoDocument.remove(item, in: $0) }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func open(_ settings: SystemSettings) {
        settings.open()
        onClose()
    }

    func setWiFiPower(_ isOn: Bool) {
        wifiMessage = nil
        wifi.isPoweredOn = isOn
        let service = wifiService
        worker.async { [weak self] in
            let succeeded = service.setPower(isOn)
            DispatchQueue.main.async {
                if !succeeded {
                    self?.wifiMessage = "Wi-Fi を切り替えられませんでした"
                }
                self?.refreshWiFi(scan: isOn)
            }
        }
    }

    func join(_ network: WiFiNetwork) {
        guard joiningNetwork == nil else { return }
        wifiMessage = nil
        joiningNetwork = network.ssid
        let service = wifiService
        worker.async { [weak self] in
            let succeeded = service.join(network.ssid)
            DispatchQueue.main.async {
                self?.joiningNetwork = nil
                if !succeeded {
                    self?.wifiMessage = "\(network.ssid) に接続できませんでした"
                }
                self?.refreshWiFi(scan: false)
            }
        }
    }

    func setBluetoothPower(_ isOn: Bool) {
        bluetoothMessage = nil
        if let report = bluetooth {
            bluetooth = BluetoothReport(isPoweredOn: isOn, devices: isOn ? report.devices : [])
        }
        worker.async { [weak self] in
            BluetoothService.setPower(isOn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.refreshBluetooth()
            }
        }
    }

    func toggle(_ device: BluetoothDevice) {
        guard !busyDevices.contains(device.address) else { return }
        bluetoothMessage = nil
        busyDevices.insert(device.address)
        worker.async { [weak self] in
            let succeeded = device.isConnected
                ? BluetoothService.disconnect(device.address)
                : BluetoothService.connect(device.address)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.busyDevices.remove(device.address)
                if !succeeded {
                    let action = device.isConnected ? "を切断" : "に接続"
                    self?.bluetoothMessage = "\(device.name) \(action)できませんでした"
                }
                self?.refreshBluetooth()
            }
        }
    }

    private func prepareServices() {
        if calendar == nil {
            let service = CalendarService()
            service.onChange = { [weak self] in
                self?.refreshAccess()
                self?.refreshCalendar()
            }
            service.observe()
            calendar = service
        }
        if location == nil {
            let access = LocationAccess()
            access.onChange = { [weak self] in
                self?.refreshAccess()
                self?.refreshWiFi(scan: true)
            }
            location = access
        }
    }

    private func tick() {
        let previous = now
        now = Date()
        ticks += 1
        if !Calendar.current.isDate(previous, inSameDayAs: now) {
            refreshCalendar()
        } else {
            rebuildAgenda()
        }
        if ticks % 5 == 0 {
            refreshTodos()
            refreshStatus()
            refreshWiFi(scan: ticks % 30 == 0)
        }
    }

    private func refreshTodos() {
        guard let url = TodoService.file() else {
            isTodoReady = false
            todos = []
            return
        }
        isTodoReady = true
        do {
            let next = TodoDocument.sorted(TodoDocument.parse(try TodoService.read(url)))
            if next != todos {
                todos = next
            }
        } catch {
            todoMessage = "todo.md を読み込めませんでした"
        }
    }

    @discardableResult
    private func updateTodos(_ change: (String) -> String?) -> Bool {
        guard let url = TodoService.file() else {
            refreshTodos()
            return false
        }
        todoMessage = nil
        var succeeded = false
        do {
            if let changed = change(try TodoService.read(url)) {
                try TodoService.write(changed, to: url)
                succeeded = true
                SyncService.shared.start()
            }
        } catch {
            todoMessage = "todo.md を更新できませんでした"
            return false
        }
        refreshTodos()
        return succeeded
    }

    private func refreshAccess() {
        calendarAccess = calendar?.state ?? .needsAccess
        locationAccess = location?.state ?? .needsAccess
    }

    private func refreshCalendar() {
        guard let calendar, let interval = visibleInterval() else { return }
        let snapshot = calendar.load(in: interval)
        events = snapshot.events
        calendarColors = snapshot.colors
        let marked = Agenda.markedDays(events: events, in: interval)
        if marked != markedDays {
            markedDays = marked
        }
        rebuildAgenda()
    }

    private func visibleInterval() -> DateInterval? {
        guard let nearby = Agenda.range(around: now) else { return nil }
        var start = nearby.start
        var end = nearby.end
        if let month = grid.interval {
            start = min(start, month.start)
            end = max(end, month.end)
        }
        if let selectedDay, let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDay) {
            start = min(start, selectedDay)
            end = max(end, next)
        }
        return DateInterval(start: start, end: end)
    }

    private func rebuildAgenda() {
        let next = Agenda.build(events: events, now: now)
        if next != agenda {
            agenda = next
        }
        let selected = selectedDay.map { Agenda.events(on: $0, from: events) } ?? []
        if selected != selectedEvents {
            selectedEvents = selected
        }
    }

    private func refreshStatus() {
        worker.async { [weak self] in
            let report = BatteryService.load()
            DispatchQueue.main.async {
                guard let self, self.battery != report else { return }
                self.battery = report
            }
        }
        refreshBluetooth()
    }

    private func refreshBluetooth() {
        worker.async { [weak self] in
            let report = BluetoothService.load()
            DispatchQueue.main.async {
                guard let self, self.bluetooth != report else { return }
                self.bluetooth = report
            }
        }
    }

    private func refreshWiFi(scan: Bool) {
        let service = wifiService
        worker.async { [weak self] in
            let state = service.load(scan: false)
            DispatchQueue.main.async {
                self?.apply(state)
            }
        }
        guard scan, !isScanning else { return }
        isScanning = true
        scanner.async { [weak self] in
            let state = service.load(scan: true)
            DispatchQueue.main.async {
                self?.isScanning = false
                self?.apply(state)
            }
        }
    }

    private func apply(_ state: WiFiState) {
        if wifi != state {
            wifi = state
        }
    }
}

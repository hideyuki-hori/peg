import AppKit
import PegCore
import SwiftUI

@MainActor
final class CalendarModel: ObservableObject {
    @Published var now = Date()
    @Published var displayedMonth = Date()
    @Published var calendarAccess: AccessState = .needsAccess
    @Published var agenda = Agenda()
    @Published var selectedDay: Date?
    @Published var selectedEvents: [AgendaEvent] = []
    @Published var markedDays: Set<Date> = []
    @Published var calendarColors: [String: Color] = [:]
    @Published var holidays: [Date: String] = [:]

    var onClose: () -> Void = {}

    private let service = CalendarService()
    private var timer: Timer?
    private var events: [AgendaEvent] = []

    init() {
        service.onChange = { [weak self] in
            self?.refreshAccess()
            self?.refreshCalendar()
        }
    }

    var grid: MonthGrid {
        MonthGrid(containing: displayedMonth, today: now)
    }

    func start() {
        service.observe()
        now = Date()
        displayedMonth = now
        selectedDay = nil
        refreshAccess()
        refreshCalendar()
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
            service.request()
        case .denied:
            SystemSettings.calendarPrivacy.open()
            onClose()
        case .granted:
            break
        }
    }

    func openMeet(_ url: URL) {
        NSWorkspace.shared.open(url)
        onClose()
    }

    private func tick() {
        let previous = now
        now = Date()
        if !Calendar.current.isDate(previous, inSameDayAs: now) {
            refreshCalendar()
        } else {
            rebuildAgenda()
        }
    }

    private func refreshAccess() {
        calendarAccess = service.state
    }

    private func computedHolidays() -> [Date: String] {
        let years = Set([displayedMonth, now].map { Calendar.current.component(.year, from: $0) })
        var result: [Date: String] = [:]
        for year in years.flatMap({ [$0 - 1, $0, $0 + 1] }) {
            result.merge(JapaneseHolidays.holidays(in: year)) { first, _ in first }
        }
        return result
    }

    private func refreshCalendar() {
        guard let interval = visibleInterval() else { return }
        let snapshot = service.load(in: interval)
        events = snapshot.events
        calendarColors = snapshot.colors
        let nextHolidays = snapshot.hasHolidayCalendar ? snapshot.holidays : computedHolidays()
        if nextHolidays != holidays {
            holidays = nextHolidays
        }
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
}

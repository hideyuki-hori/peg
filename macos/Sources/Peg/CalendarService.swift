import EventKit
import PegCore
import SwiftUI

struct CalendarSnapshot {
    let events: [AgendaEvent]
    let colors: [String: Color]
    let holidays: [Date: String]
    let hasHolidayCalendar: Bool
}

@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    var onChange: () -> Void = {}

    var state: AccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .needsAccess
        case .fullAccess:
            return .granted
        default:
            return .denied
        }
    }

    func observe() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onChange()
            }
        }
    }

    func request() {
        store.requestFullAccessToEvents { [weak self] _, error in
            if let error {
                NSLog("Peg: failed to request calendar access: %@", error.localizedDescription)
            }
            Task { @MainActor in
                self?.onChange()
            }
        }
    }

    func load(in range: DateInterval) -> CalendarSnapshot {
        guard state == .granted else {
            return CalendarSnapshot(events: [], colors: [:], holidays: [:], hasHolidayCalendar: false)
        }
        let hasHolidayCalendar = store.calendars(for: .event).contains { CalendarService.isHolidayCalendar($0.title) }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        var events: [AgendaEvent] = []
        var colors: [String: Color] = [:]
        var holidays: [Date: String] = [:]
        for event in store.events(matching: predicate) where event.status != .canceled {
            guard let calendar = event.calendar, let start = event.startDate, let end = event.endDate else { continue }
            if event.isAllDay, CalendarService.isHolidayCalendar(calendar.title) {
                var day = Calendar.current.startOfDay(for: start)
                while day < end {
                    holidays[day] = event.title ?? ""
                    guard let next = Calendar.current.date(byAdding: .day, value: 1, to: day) else { break }
                    day = next
                }
            }
            let identifier = event.eventIdentifier ?? UUID().uuidString
            events.append(AgendaEvent(
                id: identifier + ":" + String(start.timeIntervalSince1970),
                title: event.title ?? "",
                start: start,
                end: end,
                isAllDay: event.isAllDay,
                calendarID: calendar.calendarIdentifier,
                calendarName: calendar.title,
                meetURL: MeetLink.find(in: [event.url?.absoluteString, event.location, event.notes])
            ))
            if let color = calendar.cgColor {
                colors[calendar.calendarIdentifier] = Color(cgColor: color)
            }
        }
        return CalendarSnapshot(events: events, colors: colors, holidays: holidays, hasHolidayCalendar: hasHolidayCalendar)
    }

    static func isHolidayCalendar(_ title: String) -> Bool {
        title.contains("祝日") || title.lowercased().contains("holiday")
    }
}

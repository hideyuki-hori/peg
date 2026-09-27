import EventKit
import PegCore
import SwiftUI

struct CalendarSnapshot {
    let events: [AgendaEvent]
    let colors: [String: Color]
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
            return CalendarSnapshot(events: [], colors: [:])
        }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        var events: [AgendaEvent] = []
        var colors: [String: Color] = [:]
        for event in store.events(matching: predicate) where event.status != .canceled {
            guard let calendar = event.calendar, let start = event.startDate, let end = event.endDate else { continue }
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
        return CalendarSnapshot(events: events, colors: colors)
    }
}

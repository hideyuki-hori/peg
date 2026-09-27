import Foundation

public struct AgendaEvent: Identifiable, Hashable, Sendable {
    public enum Status: Sendable {
        case past
        case current
        case upcoming
    }

    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarID: String
    public let calendarName: String
    public let meetURL: URL?

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarID: String,
        calendarName: String,
        meetURL: URL?
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.calendarName = calendarName
        self.meetURL = meetURL
    }

    public func status(at now: Date) -> Status {
        if isAllDay {
            return .upcoming
        }
        if end <= now {
            return .past
        }
        if start <= now {
            return .current
        }
        return .upcoming
    }

    public func timeText(calendar: Calendar = .current) -> String {
        ClockFormat.time(start, calendar: calendar) + " - " + ClockFormat.time(end, calendar: calendar)
    }
}

public struct Agenda: Equatable, Sendable {
    public let today: [AgendaEvent]
    public let tomorrow: [AgendaEvent]

    public init(today: [AgendaEvent] = [], tomorrow: [AgendaEvent] = []) {
        self.today = today
        self.tomorrow = tomorrow
    }

    public static func range(around now: Date, calendar: Calendar = .current) -> DateInterval? {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return nil }
        return DateInterval(start: start, end: end)
    }

    public static func build(events: [AgendaEvent], now: Date, calendar: Calendar = .current) -> Agenda {
        let todayStart = calendar.startOfDay(for: now)
        guard
            let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart),
            let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrowStart)
        else { return Agenda() }
        return Agenda(
            today: select(events, from: todayStart, to: tomorrowStart),
            tomorrow: select(events, from: tomorrowStart, to: tomorrowEnd)
        )
    }

    static func select(_ events: [AgendaEvent], from start: Date, to end: Date) -> [AgendaEvent] {
        events
            .filter { $0.start < end && $0.end > start }
            .sorted { left, right in
                if left.isAllDay != right.isAllDay {
                    return left.isAllDay
                }
                if left.start != right.start {
                    return left.start < right.start
                }
                return left.title < right.title
            }
    }
}

import Foundation

public struct MonthDay: Identifiable, Hashable, Sendable {
    public let date: Date
    public let day: Int
    public let weekday: Int
    public let isInMonth: Bool
    public let isToday: Bool

    public var id: Date {
        date
    }
}

public struct MonthGrid: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let weeks: [[MonthDay]]

    public var title: String {
        "\(year)年\(month)月"
    }

    public init(containing date: Date, today: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        year = parts.year ?? 0
        month = parts.month ?? 0
        guard
            let first = calendar.date(from: parts),
            let range = calendar.range(of: .day, in: .month, for: first)
        else {
            weeks = []
            return
        }
        let leading = calendar.component(.weekday, from: first) - 1
        let total = leading + range.count
        let cellCount = ((total + 6) / 7) * 7
        var cells: [MonthDay] = []
        for index in 0..<cellCount {
            guard let day = calendar.date(byAdding: .day, value: index - leading, to: first) else { continue }
            cells.append(MonthDay(
                date: day,
                day: calendar.component(.day, from: day),
                weekday: index % 7,
                isInMonth: index >= leading && index < total,
                isToday: calendar.isDate(day, inSameDayAs: today)
            ))
        }
        weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
    }

    public static func shift(_ date: Date, months: Int, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let first = calendar.date(from: parts) else { return date }
        return calendar.date(byAdding: .month, value: months, to: first) ?? date
    }
}

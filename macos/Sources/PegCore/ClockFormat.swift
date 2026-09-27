import Foundation

public enum ClockFormat {
    public static let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    public static func header(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute, .second], from: date)
        let weekday = symbol(forWeekday: parts.weekday ?? 1)
        return String(
            format: "%04d-%02d-%02d(%@) %02d:%02d:%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0,
            weekday,
            parts.hour ?? 0,
            parts.minute ?? 0,
            parts.second ?? 0
        )
    }

    public static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    public static func duration(minutes: Int) -> String {
        let value = max(minutes, 0)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    static func symbol(forWeekday weekday: Int) -> String {
        let index = weekday - 1
        guard weekdaySymbols.indices.contains(index) else { return "" }
        return weekdaySymbols[index]
    }
}

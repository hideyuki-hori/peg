import Foundation

public enum JapaneseHolidays {
    public static func holidays(in year: Int, calendar: Calendar = .current) -> [Date: String] {
        var named: [(month: Int, day: Int, name: String)] = [
            (1, 1, "元日"),
            (2, 11, "建国記念の日"),
            (2, 23, "天皇誕生日"),
            (3, equinox(year: year, base: 20.8431), "春分の日"),
            (4, 29, "昭和の日"),
            (5, 3, "憲法記念日"),
            (5, 4, "みどりの日"),
            (5, 5, "こどもの日"),
            (8, 11, "山の日"),
            (9, equinox(year: year, base: 23.2488), "秋分の日"),
            (11, 3, "文化の日"),
            (11, 23, "勤労感謝の日")
        ]
        named.append((1, nthMonday(2, month: 1, year: year, calendar: calendar), "成人の日"))
        named.append((7, nthMonday(3, month: 7, year: year, calendar: calendar), "海の日"))
        named.append((9, nthMonday(3, month: 9, year: year, calendar: calendar), "敬老の日"))
        named.append((10, nthMonday(2, month: 10, year: year, calendar: calendar), "スポーツの日"))

        var result: [Date: String] = [:]
        for entry in named {
            guard let date = date(year, entry.month, entry.day, calendar: calendar) else { continue }
            result[date] = entry.name
        }
        for (date, _) in result.sorted(by: { $0.key < $1.key }) where calendar.component(.weekday, from: date) == 1 {
            var next = date
            while let candidate = calendar.date(byAdding: .day, value: 1, to: next) {
                next = candidate
                if result[next] == nil {
                    result[next] = "振替休日"
                    break
                }
            }
        }
        for (date, _) in result.sorted(by: { $0.key < $1.key }) {
            guard let middle = calendar.date(byAdding: .day, value: 1, to: date),
                  let after = calendar.date(byAdding: .day, value: 2, to: date),
                  result[middle] == nil, result[after] != nil,
                  calendar.component(.weekday, from: middle) != 1 else { continue }
            result[middle] = "国民の休日"
        }
        return result
    }

    static func equinox(year: Int, base: Double) -> Int {
        Int(base + 0.242194 * Double(year - 1980) - Double((year - 1980) / 4))
    }

    static func nthMonday(_ n: Int, month: Int, year: Int, calendar: Calendar) -> Int {
        guard let first = date(year, month, 1, calendar: calendar) else { return 1 }
        let weekday = calendar.component(.weekday, from: first)
        let offset = (2 - weekday + 7) % 7
        return 1 + offset + (n - 1) * 7
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

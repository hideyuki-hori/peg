import XCTest
@testable import PegCore

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
    return calendar
}

private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
    let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    return makeCalendar().date(from: parts) ?? Date(timeIntervalSince1970: 0)
}

private func makeEvent(
    _ title: String,
    start: Date,
    end: Date,
    allDay: Bool = false,
    meet: String? = nil
) -> AgendaEvent {
    AgendaEvent(
        id: title,
        title: title,
        start: start,
        end: end,
        isAllDay: allDay,
        calendarID: "c",
        calendarName: "個人",
        meetURL: meet.flatMap { URL(string: $0) }
    )
}

final class ClockFormatTests: XCTestCase {
    func testFormatsHeaderWithWeekday() {
        let date = makeDate(2026, 9, 27, 14, 32, 8)
        XCTAssertEqual(ClockFormat.header(date, calendar: makeCalendar()), "2026-09-27(日) 14:32:08")
        XCTAssertEqual(ClockFormat.header(makeDate(2026, 1, 5, 9, 5, 0), calendar: makeCalendar()), "2026-01-05(月) 09:05:00")
    }

    func testFormatsMenuBarText() {
        let calendar = makeCalendar()
        XCTAssertEqual(ClockFormat.menuBar(makeDate(2026, 9, 27, 22, 45, 10), batteryPercent: 98, calendar: calendar), "09/27(日) 22:45:10 98%")
        XCTAssertEqual(ClockFormat.menuBar(makeDate(2026, 1, 5, 9, 5, 0), batteryPercent: 7, isCharging: true, calendar: calendar), "01/05(月) 09:05:00 7%(充電中)")
        XCTAssertEqual(ClockFormat.menuBar(makeDate(2026, 1, 5, 12, 0, 0), batteryPercent: nil, calendar: calendar), "01/05(月) 12:00:00")
    }

    func testFormatsDayTitle() {
        XCTAssertEqual(ClockFormat.dayTitle(makeDate(2026, 9, 25, 8), calendar: makeCalendar()), "9月25日(金)")
        XCTAssertEqual(ClockFormat.dayTitle(makeDate(2026, 12, 1), calendar: makeCalendar()), "12月1日(火)")
    }

    func testFormatsDuration() {
        XCTAssertEqual(ClockFormat.duration(minutes: 48), "0:48")
        XCTAssertEqual(ClockFormat.duration(minutes: 995), "16:35")
        XCTAssertEqual(ClockFormat.duration(minutes: -3), "0:00")
    }
}

final class MonthGridTests: XCTestCase {
    func testBuildsSeptember2026() {
        let today = makeDate(2026, 9, 27, 14)
        let grid = MonthGrid(containing: today, today: today, calendar: makeCalendar())
        XCTAssertEqual(grid.title, "2026年9月")
        XCTAssertEqual(grid.weeks.count, 5)
        XCTAssertEqual(grid.weeks.first?.map(\.day), [30, 31, 1, 2, 3, 4, 5])
        XCTAssertEqual(grid.weeks.first?.map(\.isInMonth), [false, false, true, true, true, true, true])
        XCTAssertEqual(grid.weeks.last?.map(\.day), [27, 28, 29, 30, 1, 2, 3])
        XCTAssertEqual(grid.weeks.flatMap { $0 }.filter(\.isToday).map(\.day), [27])
        XCTAssertEqual(grid.weeks.last?.map(\.weekday), [0, 1, 2, 3, 4, 5, 6])
    }

    func testReportsIntervalOfVisibleDays() {
        let today = makeDate(2026, 9, 27, 14)
        let grid = MonthGrid(containing: today, today: today, calendar: makeCalendar())
        XCTAssertEqual(grid.interval, DateInterval(start: makeDate(2026, 8, 30), end: makeDate(2026, 10, 4)))
    }

    func testBuildsMonthsWithFourAndSixWeeks() {
        let today = makeDate(2026, 9, 27)
        XCTAssertEqual(MonthGrid(containing: makeDate(2026, 2, 10), today: today, calendar: makeCalendar()).weeks.count, 4)
        let august = MonthGrid(containing: makeDate(2026, 8, 10), today: today, calendar: makeCalendar())
        XCTAssertEqual(august.weeks.count, 6)
        XCTAssertTrue(august.weeks.flatMap { $0 }.filter(\.isToday).isEmpty)
    }

    func testShiftsAcrossYears() {
        let calendar = makeCalendar()
        let shifted = MonthGrid.shift(makeDate(2026, 12, 31), months: 1, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: shifted), DateComponents(year: 2027, month: 1, day: 1))
        let back = MonthGrid.shift(makeDate(2026, 1, 15), months: -1, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month], from: back), DateComponents(year: 2025, month: 12))
    }
}

final class MeetLinkTests: XCTestCase {
    func testFindsLinkInNotes() {
        let notes = "Google Meet に参加: https://meet.google.com/abc-defg-hij\n電話で参加する場合は..."
        XCTAssertEqual(MeetLink.find(in: notes)?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testNormalizesSchemeAndTrailingCharacters() {
        XCTAssertEqual(MeetLink.find(in: "meet.google.com/abc-defg-hij.")?.absoluteString, "https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(MeetLink.find(in: "<http://meet.google.com/abc-defg-hij>")?.absoluteString, "https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(
            MeetLink.find(in: "https://meet.google.com/abc-defg-hij?authuser=0")?.absoluteString,
            "https://meet.google.com/abc-defg-hij?authuser=0"
        )
    }

    func testIgnoresOtherHosts() {
        XCTAssertNil(MeetLink.find(in: "https://zoom.us/j/123456"))
        XCTAssertNil(MeetLink.find(in: "https://notmeet.google.com/abc"))
        XCTAssertNil(MeetLink.find(in: "https://meet.google.com/"))
    }

    func testSearchesFieldsInOrder() {
        let url = MeetLink.find(in: [nil, "会議室 A", "https://meet.google.com/xyz-abcd-efg"])
        XCTAssertEqual(url?.absoluteString, "https://meet.google.com/xyz-abcd-efg")
        XCTAssertNil(MeetLink.find(in: [nil, "会議室 A"]))
    }
}

final class AgendaTests: XCTestCase {
    func testSplitsTodayAndTomorrow() {
        let now = makeDate(2026, 9, 27, 14, 32)
        let events = [
            makeEvent("夕食", start: makeDate(2026, 9, 27, 19), end: makeDate(2026, 9, 27, 20, 30)),
            makeEvent("定例", start: makeDate(2026, 9, 28, 9, 30), end: makeDate(2026, 9, 28, 10)),
            makeEvent("朝会", start: makeDate(2026, 9, 27, 10), end: makeDate(2026, 9, 27, 11)),
            makeEvent("引っ越し準備", start: makeDate(2026, 9, 27), end: makeDate(2026, 9, 27, 23, 59, 59), allDay: true),
            makeEvent("昨日", start: makeDate(2026, 9, 26, 10), end: makeDate(2026, 9, 26, 11)),
            makeEvent("明後日", start: makeDate(2026, 9, 29, 10), end: makeDate(2026, 9, 29, 11))
        ]
        let agenda = Agenda.build(events: events, now: now, calendar: makeCalendar())
        XCTAssertEqual(agenda.today.map(\.title), ["引っ越し準備", "朝会", "夕食"])
        XCTAssertEqual(agenda.tomorrow.map(\.title), ["定例"])
    }

    func testIncludesEventsSpanningMidnightInBothDays() {
        let now = makeDate(2026, 9, 27, 14)
        let event = makeEvent("夜行バス", start: makeDate(2026, 9, 27, 23), end: makeDate(2026, 9, 28, 6))
        let agenda = Agenda.build(events: [event], now: now, calendar: makeCalendar())
        XCTAssertEqual(agenda.today.map(\.title), ["夜行バス"])
        XCTAssertEqual(agenda.tomorrow.map(\.title), ["夜行バス"])
    }

    func testReportsStatus() {
        let now = makeDate(2026, 9, 27, 14, 32)
        let past = makeEvent("a", start: makeDate(2026, 9, 27, 10), end: makeDate(2026, 9, 27, 11))
        let current = makeEvent("b", start: makeDate(2026, 9, 27, 14), end: makeDate(2026, 9, 27, 15))
        let upcoming = makeEvent("c", start: makeDate(2026, 9, 27, 19), end: makeDate(2026, 9, 27, 20))
        let allDay = makeEvent("d", start: makeDate(2026, 9, 27), end: makeDate(2026, 9, 27, 23, 59, 59), allDay: true)
        XCTAssertEqual(past.status(at: now), .past)
        XCTAssertEqual(current.status(at: now), .current)
        XCTAssertEqual(upcoming.status(at: now), .upcoming)
        XCTAssertEqual(allDay.status(at: now), .upcoming)
        XCTAssertEqual(current.timeText(calendar: makeCalendar()), "14:00 - 15:00")
    }

    func testSelectsEventsOnGivenDay() {
        let events = [
            makeEvent("午後", start: makeDate(2026, 9, 25, 15), end: makeDate(2026, 9, 25, 16)),
            makeEvent("午前", start: makeDate(2026, 9, 25, 9), end: makeDate(2026, 9, 25, 10)),
            makeEvent("別の日", start: makeDate(2026, 9, 26, 9), end: makeDate(2026, 9, 26, 10)),
            makeEvent("深夜まで", start: makeDate(2026, 9, 24, 22), end: makeDate(2026, 9, 25, 0))
        ]
        let selected = Agenda.events(on: makeDate(2026, 9, 25, 13), from: events, calendar: makeCalendar())
        XCTAssertEqual(selected.map(\.title), ["午前", "午後"])
    }

    func testMarksDaysWithEvents() {
        let interval = DateInterval(start: makeDate(2026, 8, 30), end: makeDate(2026, 10, 4))
        let events = [
            makeEvent("単日", start: makeDate(2026, 9, 10, 9), end: makeDate(2026, 9, 10, 10)),
            makeEvent("旅行", start: makeDate(2026, 9, 20), end: makeDate(2026, 9, 22, 23, 59, 59), allDay: true),
            makeEvent("月またぎ", start: makeDate(2026, 8, 28, 9), end: makeDate(2026, 8, 31, 12)),
            makeEvent("深夜まで", start: makeDate(2026, 9, 14, 22), end: makeDate(2026, 9, 15, 0)),
            makeEvent("範囲外", start: makeDate(2026, 10, 10, 9), end: makeDate(2026, 10, 10, 10))
        ]
        let days = Agenda.markedDays(events: events, in: interval, calendar: makeCalendar())
        XCTAssertEqual(days, [
            makeDate(2026, 8, 30),
            makeDate(2026, 8, 31),
            makeDate(2026, 9, 10),
            makeDate(2026, 9, 14),
            makeDate(2026, 9, 20),
            makeDate(2026, 9, 21),
            makeDate(2026, 9, 22)
        ])
    }

    func testRangeCoversTwoDays() {
        let range = Agenda.range(around: makeDate(2026, 9, 27, 14, 32), calendar: makeCalendar())
        XCTAssertEqual(range?.start, makeDate(2026, 9, 27))
        XCTAssertEqual(range?.end, makeDate(2026, 9, 29))
    }
}

final class BatteryReportTests: XCTestCase {
    private func plist(_ body: String) -> Data {
        let text = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><array><dict>\(body)</dict></array></plist>
        """
        return Data(text.utf8)
    }

    func testParsesCharging() {
        let data = plist("""
        <key>CurrentCapacity</key><integer>82</integer>
        <key>MaxCapacity</key><integer>100</integer>
        <key>IsCharging</key><true/>
        <key>ExternalConnected</key><true/>
        <key>FullyCharged</key><false/>
        <key>AvgTimeToFull</key><integer>48</integer>
        <key>AvgTimeToEmpty</key><integer>65535</integer>
        <key>NominalChargeCapacity</key><integer>5889</integer>
        <key>DesignCapacity</key><integer>6249</integer>
        <key>AdapterDetails</key><dict><key>Watts</key><integer>67</integer></dict>
        <key>Serial</key><string>ignored</string>
        """)
        let report = BatteryReport.parse(ioreg: data)
        XCTAssertEqual(report, BatteryReport(percent: 82, state: .charging, minutesRemaining: 48, adapterWatts: 67, healthPercent: 94))
        XCTAssertEqual(report?.stateText, "充電中")
        XCTAssertEqual(report?.remainingText, "フル充電まで 0:48")
        XCTAssertEqual(report?.sourceText, "電源アダプタ 67W")
    }

    func testParsesOnBattery() {
        let data = plist("""
        <key>CurrentCapacity</key><integer>99</integer>
        <key>MaxCapacity</key><integer>100</integer>
        <key>IsCharging</key><false/>
        <key>ExternalConnected</key><false/>
        <key>AvgTimeToFull</key><integer>65535</integer>
        <key>AvgTimeToEmpty</key><integer>849</integer>
        <key>AdapterDetails</key><dict></dict>
        """)
        let report = BatteryReport.parse(ioreg: data)
        XCTAssertEqual(report, BatteryReport(percent: 99, state: .onBattery, minutesRemaining: 849, adapterWatts: nil, healthPercent: nil))
        XCTAssertEqual(report?.remainingText, "残り 14:09")
        XCTAssertEqual(report?.sourceText, "バッテリー")
    }

    func testParsesCapacityInMilliampHours() {
        let data = plist("""
        <key>CurrentCapacity</key><integer>2500</integer>
        <key>MaxCapacity</key><integer>5000</integer>
        <key>ExternalConnected</key><true/>
        <key>IsCharging</key><false/>
        """)
        XCTAssertEqual(BatteryReport.parse(ioreg: data)?.percent, 50)
        XCTAssertEqual(BatteryReport.parse(ioreg: data)?.state, .pluggedIn)
    }

    func testReturnsNilForUnexpectedInput() {
        XCTAssertNil(BatteryReport.parse(ioreg: Data()))
        XCTAssertNil(BatteryReport.parse(ioreg: plist("<key>IsCharging</key><true/>")))
    }

    func testClassifiesLevels() {
        XCTAssertEqual(ChargeLevel(percent: 18), .low)
        XCTAssertEqual(ChargeLevel(percent: 20), .low)
        XCTAssertEqual(ChargeLevel(percent: 34), .medium)
        XCTAssertEqual(ChargeLevel(percent: 76), .high)
    }
}

final class BluetoothReportTests: XCTestCase {
    private let profiler = Data("""
    {"SPBluetoothDataType":[{
      "controller_properties":{"controller_state":"attrib_on"},
      "device_connected":[
        {"AirPods Pro":{"device_address":"AA:BB:CC:00:00:01","device_minorType":"Headphones","device_batteryLevelLeft":"78%","device_batteryLevelRight":"74%","device_batteryLevelCase":"52%"}},
        {"Keyboard":{"device_address":"AA:BB:CC:00:00:02","device_minorType":"Keyboard"}},
        {"Magic Mouse":{"device_address":"AA:BB:CC:00:00:03","device_minorType":"Mouse","device_batteryLevelMain":"61%"}}
      ],
      "device_not_connected":[
        {"HomePod mini":{"device_address":"AA:BB:CC:00:00:04","device_minorType":"Speaker"}},
        {"AA-BB-CC-00-00-05":{"device_address":"AA:BB:CC:00:00:05","device_minorType":"Speaker"}},
        {"Beacon":{"device_address":"AA:BB:CC:00:00:06","device_rssi":"-60"}}
      ]
    }]}
    """.utf8)

    private let hid = Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><array>
    <dict><key>BatteryPercent</key><integer>34</integer><key>DeviceAddress</key><string>aa-bb-cc-00-00-02</string></dict>
    <dict><key>BatteryPercent</key><integer>10</integer><key>DeviceAddress</key><string>aa-bb-cc-00-00-03</string></dict>
    </array></plist>
    """.utf8)

    func testParsesDevices() {
        let report = BluetoothReport.parse(systemProfiler: profiler, hidBatteries: hid)
        XCTAssertEqual(report?.isPoweredOn, true)
        XCTAssertEqual(report?.connected.map(\.name), ["AirPods Pro", "Keyboard", "Magic Mouse"])
        XCTAssertEqual(report?.disconnected.map(\.name), ["HomePod mini"])
        XCTAssertEqual(report?.connected.map(\.kind), [.headphones, .keyboard, .mouse])
        XCTAssertEqual(report?.disconnected.map(\.kind), [.speaker])
    }

    func testMergesBatteryLevels() {
        let devices = BluetoothReport.parse(systemProfiler: profiler, hidBatteries: hid)?.connected ?? []
        XCTAssertEqual(devices.map(\.battery), [nil, 34, 61])
        XCTAssertEqual(devices.first?.left, 78)
        XCTAssertEqual(devices.first?.right, 74)
        XCTAssertEqual(devices.first?.chargingCase, 52)
        XCTAssertEqual(devices.map(\.summaryBattery), [74, 34, 61])
        XCTAssertEqual(devices.map(\.hasParts), [true, false, false])
        XCTAssertEqual(devices.map(\.address), ["aa-bb-cc-00-00-01", "aa-bb-cc-00-00-02", "aa-bb-cc-00-00-03"])
    }

    func testParsesPoweredOffController() {
        let data = Data("{\"SPBluetoothDataType\":[{\"controller_properties\":{\"controller_state\":\"attrib_off\"}}]}".utf8)
        let report = BluetoothReport.parse(systemProfiler: data)
        XCTAssertEqual(report, BluetoothReport(isPoweredOn: false, devices: []))
        XCTAssertNil(BluetoothReport.parse(systemProfiler: Data("[]".utf8)))
    }
}

final class WiFiNetworksTests: XCTestCase {
    func testParsesPreferredNetworks() {
        let text = "Preferred networks on en0:\n\tHome-5G\n\tOffice Guest\n\tHome-5G\n\n"
        XCTAssertEqual(WiFiNetworks.parsePreferred(text), ["Home-5G", "Office Guest"])
        XCTAssertEqual(WiFiNetworks.parsePreferred("en0 is not a Wi-Fi interface.\n"), [])
    }

    func testSelectsKnownNearbyNetworks() {
        let scanned = [
            WiFiNetwork(ssid: "Home-2G", rssi: -70, isSecure: true),
            WiFiNetwork(ssid: "Home-2G", rssi: -52, isSecure: true),
            WiFiNetwork(ssid: "Home-5G", rssi: -40, isSecure: true),
            WiFiNetwork(ssid: "Cafe", rssi: -45, isSecure: false),
            WiFiNetwork(ssid: "Office", rssi: -82, isSecure: true)
        ]
        let result = WiFiNetworks.knownNearby(scanned: scanned, preferred: ["Home-5G", "Home-2G", "Office"], current: "Home-5G")
        XCTAssertEqual(result.map(\.ssid), ["Home-2G", "Office"])
        XCTAssertEqual(result.map(\.rssi), [-52, -82])
    }

    func testMapsSignalStrength() {
        XCTAssertEqual(WiFiNetworks.strength(rssi: -44), 1)
        XCTAssertEqual(WiFiNetworks.strength(rssi: -60), 0.66)
        XCTAssertEqual(WiFiNetworks.strength(rssi: -75), 0.33)
        XCTAssertEqual(WiFiNetworks.strength(rssi: -90), 0.1)
    }
}

final class LauncherLayoutTests: XCTestCase {
    func testPlacesCardsBesideLauncher() {
        let layout = LauncherLayout(width: 1512, height: 944)
        XCTAssertEqual(layout.launcherX, 436)
        XCTAssertEqual(layout.launcherY, 199)
        XCTAssertEqual(layout.clockY, 119)
        XCTAssertEqual(layout.cardWidth, 340)
        XCTAssertEqual(layout.leftX, 72)
        XCTAssertEqual(layout.rightX, 1100)
        XCTAssertEqual(layout.columnY, 119)
        XCTAssertEqual(layout.columnHeight, 809)
        XCTAssertEqual(layout.todoY, 635)
        XCTAssertEqual(layout.todoHeight, 293)
    }

    func testLimitsTodoHeight() {
        XCTAssertEqual(LauncherLayout(width: 2560, height: 1400).todoHeight, 320)
        XCTAssertEqual(LauncherLayout(width: 1512, height: 860).todoHeight, 241)
        XCTAssertEqual(LauncherLayout(width: 1512, height: 760).todoHeight, 179)
        XCTAssertNil(LauncherLayout(width: 1512, height: 740).todoHeight)
    }

    func testKeepsCardsNextToLauncherOnWideScreens() {
        let layout = LauncherLayout(width: 2560, height: 1400)
        XCTAssertEqual(layout.launcherX, 960)
        XCTAssertEqual(layout.cardWidth, 340)
        XCTAssertEqual(layout.leftX, 596)
        XCTAssertEqual(layout.rightX, 1624)
    }

    func testShrinksCardsOnNarrowScreens() {
        XCTAssertEqual(LauncherLayout(width: 1440, height: 860).cardWidth, 340)
        XCTAssertEqual(LauncherLayout(width: 1360, height: 860).cardWidth, 320)
        XCTAssertEqual(LauncherLayout(width: 1280, height: 760).cardWidth, 280)
        XCTAssertEqual(LauncherLayout(width: 1280, height: 760).leftX, 16)
    }

    func testHidesCardsWhenTheyDoNotFit() {
        let layout = LauncherLayout(width: 1200, height: 760)
        XCTAssertNil(layout.cardWidth)
        XCTAssertEqual(layout.launcherX, 280)
    }

    func testHidesClockWhenThereIsNoRoomAbove() {
        let layout = LauncherLayout(width: 1512, height: 600)
        XCTAssertEqual(layout.launcherY, 68)
        XCTAssertNil(layout.clockY)
        XCTAssertEqual(layout.columnY, 68)
    }
}

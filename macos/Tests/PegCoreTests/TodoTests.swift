import XCTest
@testable import PegCore

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
    return calendar
}

private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    makeCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date(timeIntervalSince1970: 0)
}

final class TodoDocumentTests: XCTestCase {
    private let text = """
    # ToDo

    - [ ] 請求書を送る 📅 2026-09-26
    - [x] 牛乳を買う
    メモ: これはタスクではない
    - ふつうの箇条書き
      - [ ] 歯医者を予約する
    * [X] 完了した別記法
    - [ ] 📅 2026-09-30 先頭に期限
    - [ ]
    """

    func testParsesTasksOnly() {
        let items = TodoDocument.parse(text)
        XCTAssertEqual(items.map(\.title), ["請求書を送る", "牛乳を買う", "歯医者を予約する", "完了した別記法", "先頭に期限"])
        XCTAssertEqual(items.map(\.isDone), [false, true, false, true, false])
        XCTAssertEqual(items.map(\.due), ["2026-09-26", nil, nil, nil, "2026-09-30"])
        XCTAssertEqual(items.map(\.dueText), ["09/26", nil, nil, nil, "09/30"])
    }

    func testPutsIncompleteTasksFirst() {
        let items = TodoDocument.sorted(TodoDocument.parse(text))
        XCTAssertEqual(items.map(\.title), ["請求書を送る", "歯医者を予約する", "先頭に期限", "牛乳を買う", "完了した別記法"])
    }

    func testReportsOverdue() {
        let items = TodoDocument.parse("- [ ] a 📅 2026-09-26\n- [ ] b 📅 2026-09-27\n- [x] c 📅 2026-09-01\n- [ ] d")
        XCTAssertEqual(items.map { $0.isOverdue(today: "2026-09-27") }, [true, false, false, false])
    }

    func testTogglesOnlyTargetLine() {
        let items = TodoDocument.parse(text)
        let toggled = TodoDocument.toggle(items[2], in: text)
        XCTAssertEqual(toggled, text.replacingOccurrences(of: "  - [ ] 歯医者を予約する", with: "  - [x] 歯医者を予約する"))
        let reopened = TodoDocument.toggle(items[3], in: text)
        XCTAssertEqual(reopened, text.replacingOccurrences(of: "* [X] 完了した別記法", with: "* [ ] 完了した別記法"))
    }

    func testTogglesMatchingOccurrenceOfDuplicatedLines() {
        let source = "- [ ] 同じ\n- [ ] 同じ\n- [ ] 同じ"
        let items = TodoDocument.parse(source)
        XCTAssertEqual(Set(items.map(\.id)).count, 3)
        XCTAssertEqual(TodoDocument.toggle(items[1], in: source), "- [ ] 同じ\n- [x] 同じ\n- [ ] 同じ")
        XCTAssertEqual(TodoDocument.toggle(items[2], in: "- [ ] 同じ"), "- [x] 同じ")
    }

    func testReturnsNilWhenLineWasChangedElsewhere() {
        let items = TodoDocument.parse("- [ ] 請求書を送る")
        XCTAssertNil(TodoDocument.toggle(items[0], in: "- [x] 請求書を送る"))
        XCTAssertNil(TodoDocument.remove(items[0], in: "# 空"))
    }

    func testRemovesLine() {
        let items = TodoDocument.parse("# ToDo\n- [ ] a\n- [x] b\n")
        XCTAssertEqual(TodoDocument.remove(items[0], in: "# ToDo\n- [ ] a\n- [x] b\n"), "# ToDo\n- [x] b\n")
    }

    func testAddsTask() {
        let today = makeDate(2026, 9, 27, 14)
        let calendar = makeCalendar()
        XCTAssertEqual(TodoDocument.add("  牛乳を買う ", to: "", today: today, calendar: calendar), "- [ ] 牛乳を買う\n")
        XCTAssertEqual(TodoDocument.add("b", to: "- [ ] a", today: today, calendar: calendar), "- [ ] a\n- [ ] b\n")
        XCTAssertEqual(TodoDocument.add("b", to: "- [ ] a\n", today: today, calendar: calendar), "- [ ] a\n- [ ] b\n")
        XCTAssertNil(TodoDocument.add("   ", to: "", today: today, calendar: calendar))
    }

    func testAddsTaskWithDueDate() {
        let today = makeDate(2026, 9, 27, 14)
        let calendar = makeCalendar()
        XCTAssertEqual(TodoDocument.add("請求書 @9/30", to: "", today: today, calendar: calendar), "- [ ] 請求書 📅 2026-09-30\n")
        XCTAssertEqual(TodoDocument.add("当日 @09/27", to: "", today: today, calendar: calendar), "- [ ] 当日 📅 2026-09-27\n")
        XCTAssertEqual(TodoDocument.add("来年 @1/5", to: "", today: today, calendar: calendar), "- [ ] 来年 📅 2027-01-05\n")
        XCTAssertEqual(TodoDocument.add("指定 @2026-12-24", to: "", today: today, calendar: calendar), "- [ ] 指定 📅 2026-12-24\n")
        XCTAssertEqual(TodoDocument.add("連絡 @tanaka", to: "", today: today, calendar: calendar), "- [ ] 連絡 @tanaka\n")
        XCTAssertEqual(TodoDocument.add("無効 @2/30", to: "", today: today, calendar: calendar), "- [ ] 無効 @2/30\n")
        XCTAssertEqual(TodoDocument.add(" @9/30", to: "", today: today, calendar: calendar), "- [ ] @9/30\n")
    }

    func testRoundTripsAddedTask() {
        let today = makeDate(2026, 9, 27, 14)
        let added = TodoDocument.add("請求書 @9/30", to: "", today: today, calendar: makeCalendar()) ?? ""
        let items = TodoDocument.parse(added)
        XCTAssertEqual(items.map(\.title), ["請求書"])
        XCTAssertEqual(items.map(\.due), ["2026-09-30"])
        XCTAssertEqual(TodoDocument.dayString(today, calendar: makeCalendar()), "2026-09-27")
    }
}

final class PegConfigTests: XCTestCase {
    func testResolvesTodoFile() {
        XCTAssertEqual(PegConfig(vaultPath: "/Users/test/vaults").todoFile()?.path, "/Users/test/vaults/peg/todo.md")
        XCTAssertEqual(PegConfig(vaultPath: "~/vaults/").todoFile(homeDirectory: "/Users/test")?.path, "/Users/test/vaults/peg/todo.md")
        XCTAssertNil(PegConfig(vaultPath: nil).todoFile())
        XCTAssertNil(PegConfig(vaultPath: "  ").todoFile())
        XCTAssertNil(PegConfig(vaultPath: "relative/path").todoFile())
    }

    func testLoadsFromFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("peg-config-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{\"vaultPath\": \"~/vaults\", \"unknown\": 1}".utf8).write(to: url)
        XCTAssertEqual(PegConfig.load(from: url), PegConfig(vaultPath: "~/vaults"))
        XCTAssertEqual(PegConfig.load(from: url.appendingPathExtension("missing")), PegConfig())
    }
}

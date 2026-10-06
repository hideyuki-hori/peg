import XCTest
@testable import PegCore

final class AppListTests: XCTestCase {
    func testParsesEscapedPathsAndRemovesDuplicates() {
        let text = """
        /Applications/Blender.app
        /Applications/Claude.app
        /Applications/CLIP\\ STUDIO\\ 1.5/App/CLIP\\ STUDIO\\ PAINT.app
        /Applications/Google\\ Chrome.app
        /Applications/Google\\ Chrome.app

        """
        let entries = AppList.parse(text)
        XCTAssertEqual(entries.map(\.url.path), [
            "/Applications/Blender.app",
            "/Applications/Claude.app",
            "/Applications/CLIP STUDIO 1.5/App/CLIP STUDIO PAINT.app",
            "/Applications/Google Chrome.app"
        ])
        XCTAssertEqual(entries.map(\.name), ["Blender", "Claude", "CLIP STUDIO PAINT", "Google Chrome"])
    }

    func testParsesQuotedAndHomePaths() {
        let text = "\"/Applications/Logic Pro.app\"\n~/Applications/Foo.app/\nrelative.app"
        let entries = AppList.parse(text, homeDirectory: "/Users/test")
        XCTAssertEqual(entries.map(\.url.path), [
            "/Applications/Logic Pro.app",
            "/Users/test/Applications/Foo.app"
        ])
    }
}

final class MatcherTests: XCTestCase {
    func testRanksPrefixThenContainsThenSubsequence() {
        let items = ["Google Chrome", "Obsidian", "Logic Pro", "iTerm", "GitHub Desktop"]
        XCTAssertEqual(Matcher.filter(items, query: "", key: { $0 }), items)
        XCTAssertEqual(Matcher.filter(items, query: "o", key: { $0 }).first, "Obsidian")
        XCTAssertEqual(Matcher.filter(items, query: "chrome", key: { $0 }), ["Google Chrome"])
        XCTAssertEqual(Matcher.filter(items, query: "ghd", key: { $0 }), ["GitHub Desktop"])
        XCTAssertEqual(Matcher.filter(items, query: "zzz", key: { $0 }), [])
    }
}

final class ClipboardStoreTests: XCTestCase {
    func testMovesDuplicatesToTopAndRespectsLimit() {
        var store = ClipboardStore(limit: 3)
        store.add("a")
        store.add("b")
        store.add("c")
        store.add("a")
        store.add("   ")
        XCTAssertEqual(store.entries.map(\.text), ["a", "c", "b"])
        store.add("d")
        XCTAssertEqual(store.entries.map(\.text), ["d", "a", "c"])
    }

    func testSavesAndLoads() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("peg-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var store = ClipboardStore()
        store.add("hello\nworld")
        try store.save(to: url)
        let loaded = ClipboardStore.load(from: url)
        XCTAssertEqual(loaded.entries.map(\.text), ["hello\nworld"])
        XCTAssertEqual(loaded.entries.first?.preview, "hello world")
    }
}

final class DoubleTapDetectorTests: XCTestCase {
    func testFiresOnQuickDoubleTap() {
        var detector = DoubleTapDetector()
        XCTAssertFalse(detector.handle(.down, at: 0))
        XCTAssertFalse(detector.handle(.up, at: 0.1))
        XCTAssertFalse(detector.handle(.down, at: 0.2))
        XCTAssertTrue(detector.handle(.up, at: 0.3))
    }

    func testIgnoresSlowTaps() {
        var detector = DoubleTapDetector()
        _ = detector.handle(.down, at: 0)
        _ = detector.handle(.up, at: 0.1)
        _ = detector.handle(.down, at: 1)
        XCTAssertFalse(detector.handle(.up, at: 1.1))
    }

    func testIgnoresLongHold() {
        var detector = DoubleTapDetector()
        _ = detector.handle(.down, at: 0)
        _ = detector.handle(.up, at: 0.1)
        _ = detector.handle(.down, at: 0.2)
        XCTAssertFalse(detector.handle(.up, at: 0.9))
    }

    func testResetsWhenOtherKeyIsPressed() {
        var detector = DoubleTapDetector()
        _ = detector.handle(.down, at: 0)
        _ = detector.handle(.up, at: 0.1)
        _ = detector.handle(.down, at: 0.15)
        _ = detector.handle(.other, at: 0.2)
        XCTAssertFalse(detector.handle(.up, at: 0.25))
    }
}

final class HintLabelsTests: XCTestCase {
    func testUsesSingleLettersWhenTheyFit() {
        XCTAssertEqual(HintLabels.make(count: 0), [])
        XCTAssertEqual(HintLabels.make(count: 3), ["a", "s", "d"])
        XCTAssertEqual(HintLabels.make(count: 9).count, 9)
    }

    func testKeepsAsManySingleLettersAsPossibleAndStaysPrefixFree() {
        let labels = HintLabels.make(count: 12)
        XCTAssertEqual(labels.count, 12)
        XCTAssertEqual(labels.prefix(8), ["a", "s", "d", "f", "g", "h", "j", "k"])
        XCTAssertEqual(labels[8], "la")
        for label in labels {
            XCTAssertFalse(labels.contains { $0 != label && $0.hasPrefix(label) }, label)
        }
        XCTAssertEqual(Set(labels).count, 12)
    }

    func testCapsAtTwoLetters() {
        let labels = HintLabels.make(count: 100)
        XCTAssertEqual(labels.count, 81)
        XCTAssertTrue(labels.allSatisfy { $0.count <= 2 })
        XCTAssertEqual(Set(labels).count, 81)
    }

    func testMatchesTypedInput() {
        let labels = HintLabels.make(count: 12)
        XCTAssertEqual(HintLabels.match("", in: labels), .partial)
        XCTAssertEqual(HintLabels.match("s", in: labels), .exact(1))
        XCTAssertEqual(HintLabels.match("l", in: labels), .partial)
        XCTAssertEqual(HintLabels.match("ls", in: labels), .exact(9))
        XCTAssertEqual(HintLabels.match("q", in: labels), .none)
    }
}

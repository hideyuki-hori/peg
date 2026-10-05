import XCTest
@testable import PegNotes

final class UUIDv7Tests: XCTestCase {
    func testEncodesTimestampVersionAndVariant() {
        let id = UUIDv7.make(milliseconds: 0x0199_A3F2_7C1E, random: Array(repeating: 0xFF, count: 10))
        XCTAssertEqual(id, "0199a3f2-7c1e-7fff-bfff-ffffffffffff")
    }

    func testSortsByCreationTime() {
        let earlier = UUIDv7.make(at: Date(timeIntervalSince1970: 1_700_000_000))
        let later = UUIDv7.make(at: Date(timeIntervalSince1970: 1_700_000_001))
        XCTAssertLessThan(earlier, later)
        XCTAssertNotNil(UUID(uuidString: earlier))
    }
}

final class NoteTitleTests: XCTestCase {
    func testUsesFirstNonEmptyLineWithoutMarkers() {
        XCTAssertEqual(NoteTitle.make(from: "\n\n# 買い物\n- 牛乳"), "買い物")
        XCTAssertEqual(NoteTitle.make(from: "- [ ] 請求書を送る"), "請求書を送る")
        XCTAssertEqual(NoteTitle.make(from: "1. 最初"), "最初")
        XCTAssertEqual(NoteTitle.make(from: "> 引用"), "引用")
        XCTAssertEqual(NoteTitle.make(from: "ただの文"), "ただの文")
    }

    func testFallsBackWhenEmpty() {
        XCTAssertEqual(NoteTitle.make(from: ""), NoteTitle.untitled)
        XCTAssertEqual(NoteTitle.make(from: " \n#\n"), "#")
    }
}

final class NoteStoreTests: XCTestCase {
    private var directory = URL(fileURLWithPath: NSTemporaryDirectory())

    override func setUp() {
        directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("peg-notes-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testCreatesWritesAndListsInCreationOrder() async throws {
        let store = NoteStore(directory: directory, usesTrash: false)
        let first = try await store.create(at: Date(timeIntervalSince1970: 1_700_000_000))
        let second = try await store.create(at: Date(timeIntervalSince1970: 1_700_000_100))
        try await store.write(Note(id: first.id, text: "# 一つ目\n本文"))
        try await store.write(Note(id: second.id, text: "二つ目"))
        let notes = await store.list()
        XCTAssertEqual(notes, [
            NoteSummary(id: first.id, title: "一つ目"),
            NoteSummary(id: second.id, title: "二つ目")
        ])
        let loaded = await store.read(first.id)
        XCTAssertEqual(loaded?.text, "# 一つ目\n本文")
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(first.id + ".md").path))
    }

    func testListsNothingWhenDirectoryIsMissing() async {
        let store = NoteStore(directory: directory, usesTrash: false)
        let notes = await store.list()
        XCTAssertEqual(notes, [])
    }

    func testDeletesAndRemovesOnlyEmptyNotes() async throws {
        let store = NoteStore(directory: directory, usesTrash: false)
        let empty = try await store.create()
        let filled = try await store.create()
        try await store.write(Note(id: empty.id, text: " \n"))
        try await store.write(Note(id: filled.id, text: "a"))
        let removedEmpty = try await store.removeIfEmpty(empty.id)
        let removedFilled = try await store.removeIfEmpty(filled.id)
        XCTAssertTrue(removedEmpty)
        XCTAssertFalse(removedFilled)
        try await store.delete(filled.id)
        let notes = await store.list()
        XCTAssertEqual(notes, [])
    }

    func testRejectsIdsOutsideTheDirectory() async {
        let store = NoteStore(directory: directory, usesTrash: false)
        let note = await store.read("../secret")
        XCTAssertNil(note)
        do {
            try await store.write(Note(id: "a/b", text: "x"))
            XCTFail("write should throw")
        } catch {}
    }
}

final class MarkdownStylerTests: XCTestCase {
    private func styled(_ text: String) -> [String] {
        MarkdownStyler.spans(in: text).map { span in
            let range = NSRange(location: span.location, length: span.length)
            return "\(span.kind):\(NSString(string: text).substring(with: range))"
        }
    }

    func testHeadings() {
        XCTAssertEqual(styled("# aaa"), ["heading(1):# aaa", "marker:# "])
        XCTAssertEqual(styled("### 見出し"), ["heading(3):### 見出し", "marker:### "])
        XCTAssertEqual(styled("#aaa"), [])
        XCTAssertEqual(styled("####### aaa"), [])
    }

    func testLists() {
        XCTAssertEqual(styled("- a\n  * b\n1. c\n2) d"), ["listMarker:-", "listMarker:*", "listMarker:1.", "listMarker:2)"])
    }

    func testCheckboxes() {
        XCTAssertEqual(styled("- [ ] やる"), ["listMarker:-", "checkbox(false):[ ]"])
        XCTAssertEqual(styled("- [x] 済み"), ["listMarker:-", "checkbox(true):[x]", "done:済み"])
    }

    func testQuote() {
        XCTAssertEqual(styled("> 引用"), ["quote:引用", "marker:> "])
    }

    func testInlineStyles() {
        XCTAssertEqual(styled("a **太字** b"), ["bold:太字", "marker:**", "marker:**"])
        XCTAssertEqual(styled("a *斜体* b"), ["italic:斜体", "marker:*", "marker:*"])
        XCTAssertEqual(styled("a _斜体_ b"), ["italic:斜体", "marker:_", "marker:_"])
        XCTAssertEqual(styled("a `code` b"), ["code:`code`", "marker:`", "marker:`"])
        XCTAssertEqual(styled("snake_case_name と 2 * 3 * 4"), [])
    }

    func testInlineCodeSuppressesOtherStyles() {
        XCTAssertEqual(styled("`**x**`"), ["code:`**x**`", "marker:`", "marker:`"])
    }

    func testCodeBlockSuppressesOtherStyles() {
        let text = "前\n```swift\n# not heading\n- **x**\n```\n# 後"
        XCTAssertEqual(styled(text), [
            "codeBlock:```swift\n# not heading\n- **x**\n```",
            "marker:```swift",
            "marker:```",
            "heading(1):# 後",
            "marker:# "
        ])
    }

    func testUnterminatedCodeBlockRunsToEnd() {
        XCTAssertEqual(styled("```\n# a"), ["codeBlock:```\n# a", "marker:```"])
    }

    func testOffsetsAreUTF16() {
        let spans = MarkdownStyler.spans(in: "😀\n# a")
        XCTAssertEqual(spans.first, StyleSpan(location: 3, length: 3, kind: .heading(1)))
    }
}

final class StickyStateStoreTests: XCTestCase {
    func testSavesAndLoadsState() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("peg-sticky-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StickyStateStore(file: directory.appendingPathComponent("notes/stickies.json"))
        let empty = await store.load()
        XCTAssertEqual(empty, StickyState())
        let state = StickyState(
            placements: [StickyPlacement(id: "a", x: 10, y: 20, width: 320, height: 300)],
            focused: "a"
        )
        try await store.save(state)
        let loaded = await store.load()
        XCTAssertEqual(loaded, state)
    }
}

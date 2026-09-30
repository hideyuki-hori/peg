import XCTest
@testable import PegCore

final class NoteTreeTests: XCTestCase {
    private func summary(_ rows: [NoteRow]) -> [String] {
        rows.map { String(repeating: "  ", count: $0.depth) + $0.name + ($0.isDirectory ? "/" : "") }
    }

    func testListsDirectoriesFirstAndHidesCollapsedChildren() {
        let rows = NoteTree.rows(
            files: ["b.md", "a.md", "notes/x.md", "notes/sub/y.md", "Archive/old.md"],
            directories: ["notes", "notes/sub", "Archive", "empty"],
            expanded: []
        )
        XCTAssertEqual(summary(rows), ["Archive/", "empty/", "notes/", "a.md", "b.md"])
        XCTAssertEqual(rows.map(\.isExpanded), [false, false, false, false, false])
    }

    func testShowsChildrenOfExpandedDirectories() {
        let rows = NoteTree.rows(
            files: ["a.md", "notes/x.md", "notes/sub/y.md"],
            directories: ["notes", "notes/sub"],
            expanded: ["notes", "notes/sub"]
        )
        XCTAssertEqual(summary(rows), ["notes/", "  sub/", "    y.md", "  x.md", "a.md"])
        XCTAssertEqual(rows.map(\.path), ["notes", "notes/sub", "notes/sub/y.md", "notes/x.md", "a.md"])
    }

    func testDoesNotShowChildrenWhenOnlyInnerDirectoryIsExpanded() {
        let rows = NoteTree.rows(files: ["notes/sub/y.md"], directories: [], expanded: ["notes/sub"])
        XCTAssertEqual(summary(rows), ["notes/"])
    }

    func testSortsNamesNaturally() {
        let rows = NoteTree.rows(files: ["note10.md", "note2.md", "Beta.md", "alpha.md"], directories: [], expanded: [])
        XCTAssertEqual(summary(rows), ["alpha.md", "Beta.md", "note2.md", "note10.md"])
    }

    func testHidesDotFiles() {
        XCTAssertTrue(NoteTree.isVisible("notes/a.md"))
        XCTAssertFalse(NoteTree.isVisible(".obsidian/app.json"))
        XCTAssertFalse(NoteTree.isVisible("notes/.DS_Store"))
        XCTAssertFalse(NoteTree.isVisible(".trash/a.md"))
    }

    func testListsAncestors() {
        XCTAssertEqual(NoteTree.ancestors(of: "a/b/c.md"), ["a/b", "a"])
        XCTAssertEqual(NoteTree.ancestors(of: "c.md"), [])
        XCTAssertEqual(NoteTree.parent(of: "a/b/c.md"), "a/b")
        XCTAssertEqual(NoteTree.parent(of: "c.md"), "")
    }
}

final class NoteNameTests: XCTestCase {
    func testAddsExtensionAndDirectory() {
        XCTAssertEqual(NoteName.path(for: "メモ", in: ""), "メモ.md")
        XCTAssertEqual(NoteName.path(for: " idea ", in: "notes"), "notes/idea.md")
        XCTAssertEqual(NoteName.path(for: "data.txt", in: ""), "data.txt")
        XCTAssertEqual(NoteName.path(for: "sub/deep/a", in: "notes"), "notes/sub/deep/a.md")
    }

    func testRejectsUnsafeNames() {
        XCTAssertNil(NoteName.path(for: "", in: ""))
        XCTAssertNil(NoteName.path(for: "   ", in: ""))
        XCTAssertNil(NoteName.path(for: "../a", in: "notes"))
        XCTAssertNil(NoteName.path(for: "/a", in: ""))
        XCTAssertNil(NoteName.path(for: "a//b", in: ""))
        XCTAssertNil(NoteName.path(for: ".hidden", in: ""))
        XCTAssertNil(NoteName.path(for: "a:b", in: ""))
    }
}

final class NoteSaveTests: XCTestCase {
    func testDecides() {
        XCTAssertEqual(NoteSave.decide(base: "a", disk: "a", text: "b"), .write)
        XCTAssertEqual(NoteSave.decide(base: "a", disk: "a", text: "a"), .unchanged)
        XCTAssertEqual(NoteSave.decide(base: "a", disk: "c", text: "b"), .conflict)
        XCTAssertEqual(NoteSave.decide(base: "a", disk: "b", text: "b"), .unchanged)
        XCTAssertEqual(NoteSave.decide(base: "a", disk: nil, text: "b"), .write)
        XCTAssertEqual(NoteSave.decide(base: nil, disk: nil, text: ""), .write)
    }
}

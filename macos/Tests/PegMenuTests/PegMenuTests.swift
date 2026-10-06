import XCTest
@testable import PegMenu

struct FakeNode: MenuNode {
    let title: String
    let role: String
    var isEnabled = true
    var items: [FakeNode] = []

    func children() -> [FakeNode] {
        items
    }
}

final class MenuFlattenerTests: XCTestCase {
    private func bar(_ items: [FakeNode]) -> [FakeNode] {
        items
    }

    private func menu(_ title: String, role: String = "AXMenuBarItem", _ items: [FakeNode]) -> FakeNode {
        FakeNode(title: title, role: role, items: [FakeNode(title: "", role: "AXMenu", items: items)])
    }

    private func item(_ title: String, enabled: Bool = true) -> FakeNode {
        FakeNode(title: title, role: "AXMenuItem", isEnabled: enabled)
    }

    func testFlattensNestedMenusIntoPaths() {
        let roots = bar([
            menu("ファイル", [
                item("新規"),
                item("", role: "AXMenuItem"),
                menu("書き出す", role: "AXMenuItem", [item("PDF"), item("PNG", enabled: false)]),
                item("閉じる", enabled: false)
            ]),
            menu("", []),
            menu("編集", [item("コピー")])
        ])
        let items = MenuFlattener.flatten(roots).map(\.item)
        XCTAssertEqual(items.map(\.title), ["ファイル > 新規", "ファイル > 書き出す > PDF", "編集 > コピー"])
        XCTAssertEqual(items[1].name, "PDF")
        XCTAssertEqual(items[1].location, "ファイル > 書き出す")
    }

    func testDropsHiddenAlternatesWithoutConfirmation() {
        let roots = bar([menu("Apple", [item("再起動…"), item("再起動"), item("スリープ"), item("強制終了…"), item("Finderを強制終了")])])
        XCTAssertEqual(
            MenuFlattener.flatten(roots).map(\.item.name),
            ["再起動…", "スリープ", "強制終了…", "Finderを強制終了"]
        )
    }

    func testStopsAtLimitAndDepth() {
        let deep = menu("a", role: "AXMenuItem", [menu("b", role: "AXMenuItem", [item("c")])])
        let roots = bar([menu("ファイル", [deep, item("x"), item("y")])])
        XCTAssertEqual(MenuFlattener.flatten(roots, limit: 2).map(\.item.title), ["ファイル > a > b > c", "ファイル > x"])
        XCTAssertEqual(MenuFlattener.flatten(roots, maxDepth: 2).map(\.item.title), ["ファイル > x", "ファイル > y"])
    }

    private func item(_ title: String, role: String) -> FakeNode {
        FakeNode(title: title, role: role)
    }
}

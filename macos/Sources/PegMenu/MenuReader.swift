import ApplicationServices
import Foundation
import PegAXShim

struct AXMenuNode: MenuNode {
    let element: AXUIElement

    var title: String {
        string { PegAXCopyTitle(element, $0, $1) }
    }

    var role: String {
        string { PegAXCopyRole(element, $0, $1) }
    }

    var isEnabled: Bool {
        PegAXIsEnabled(element)
    }

    func children() -> [AXMenuNode] {
        guard let array = PegAXCopyChildren(element) else { return [] }
        return (0..<CFArrayGetCount(array)).compactMap { index in
            PegAXCopyElementAt(array, index).map { AXMenuNode(element: $0) }
        }
    }

    func press() -> Bool {
        PegAXPress(element)
    }

    private func string(_ read: (UnsafeMutablePointer<CChar>, Int) -> Bool) -> String {
        var buffer = [CChar](repeating: 0, count: 1024)
        let ok = buffer.withUnsafeMutableBufferPointer { pointer in
            pointer.baseAddress.map { read($0, pointer.count) } ?? false
        }
        guard ok else { return "" }
        return String(cString: buffer)
    }
}

public final class MenuSnapshot: @unchecked Sendable {
    public let pid: pid_t
    public let items: [MenuItem]
    private let nodes: [String: AXMenuNode]

    init(pid: pid_t, entries: [(item: MenuItem, node: AXMenuNode)]) {
        self.pid = pid
        items = entries.map(\.item)
        nodes = Dictionary(entries.map { ($0.item.id, $0.node) }, uniquingKeysWith: { first, _ in first })
    }

    public func press(_ item: MenuItem) async -> Bool {
        guard let node = nodes[item.id] else { return false }
        return await Task.detached(priority: .userInitiated) {
            node.press()
        }.value
    }
}

public enum MenuReader {
    public static func read(pid: pid_t, timeout: Float = 0.5, limit: Int = 3000) async -> MenuSnapshot? {
        await Task.detached(priority: .userInitiated) {
            guard let bar = PegAXCopyMenuBar(pid, timeout) else { return nil }
            let roots = AXMenuNode(element: bar).children()
            return MenuSnapshot(pid: pid, entries: MenuFlattener.flatten(roots, limit: limit))
        }.value
    }
}

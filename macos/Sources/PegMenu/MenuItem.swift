import Foundation

public struct MenuItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let path: [String]

    public init(path: [String]) {
        self.path = path
    }

    public var id: String {
        path.joined(separator: "\u{1F}")
    }

    public var title: String {
        path.joined(separator: " > ")
    }

    public var name: String {
        path.last ?? ""
    }

    public var location: String {
        path.dropLast().joined(separator: " > ")
    }
}

public protocol MenuNode {
    var title: String { get }
    var role: String { get }
    var isEnabled: Bool { get }
    func children() -> [Self]
}

public enum MenuFlattener {
    public static func flatten<Node: MenuNode>(_ roots: [Node], limit: Int = 3000, maxDepth: Int = 6) -> [(item: MenuItem, node: Node)] {
        var result: [(item: MenuItem, node: Node)] = []
        for root in roots where root.role == "AXMenuBarItem" && !root.title.isEmpty {
            walk(root, path: [root.title], depth: 1, limit: limit, maxDepth: maxDepth, into: &result)
        }
        let confirmed = Set(result.map(\.item.path).filter { $0.last?.hasSuffix("…") == true })
        return result.filter { entry in
            guard let name = entry.item.path.last, !name.hasSuffix("…") else { return true }
            return !confirmed.contains(entry.item.path.dropLast() + [name + "…"])
        }
    }

    private static func walk<Node: MenuNode>(
        _ node: Node,
        path: [String],
        depth: Int,
        limit: Int,
        maxDepth: Int,
        into result: inout [(item: MenuItem, node: Node)]
    ) {
        guard depth <= maxDepth, result.count < limit else { return }
        for child in node.children() {
            guard result.count < limit else { return }
            switch child.role {
            case "AXMenu":
                walk(child, path: path, depth: depth, limit: limit, maxDepth: maxDepth, into: &result)
            case "AXMenuItem", "AXMenuBarItem":
                guard !child.title.isEmpty else { continue }
                let submenus = child.children().filter { $0.role == "AXMenu" }
                if submenus.isEmpty {
                    if child.isEnabled {
                        result.append((MenuItem(path: path + [child.title]), child))
                    }
                } else {
                    walk(child, path: path + [child.title], depth: depth + 1, limit: limit, maxDepth: maxDepth, into: &result)
                }
            default:
                continue
            }
        }
    }
}

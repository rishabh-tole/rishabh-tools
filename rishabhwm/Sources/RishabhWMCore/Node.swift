public typealias WindowID = UInt32

public enum ContainerLayout: Equatable {
    case tiles
    case accordion
}

/// Immutable layout tree node: either a window leaf or a container of children.
/// `weight` is the node's share of its parent's length (relative to siblings).
public struct Node: Equatable {
    public enum Kind: Equatable {
        case window(WindowID)
        case container(Orientation, ContainerLayout)
    }

    public let kind: Kind
    public let weight: Double
    public let children: [Node]

    public init(kind: Kind, weight: Double, children: [Node]) {
        self.kind = kind
        self.weight = weight
        self.children = children
    }

    public static func window(_ id: WindowID, weight: Double = 1) -> Node {
        Node(kind: .window(id), weight: weight, children: [])
    }

    public static func container(
        _ orientation: Orientation,
        _ layout: ContainerLayout = .tiles,
        _ children: [Node] = [],
        weight: Double = 1
    ) -> Node {
        Node(kind: .container(orientation, layout), weight: weight, children: children)
    }

    public var windowID: WindowID? {
        if case .window(let id) = kind { return id }
        return nil
    }

    public var isContainer: Bool { windowID == nil }

    public var orientation: Orientation? {
        if case .container(let orientation, _) = kind { return orientation }
        return nil
    }

    public var layout: ContainerLayout? {
        if case .container(_, let layout) = kind { return layout }
        return nil
    }

    /// All windows in depth-first (visual) order.
    public var windows: [WindowID] {
        if let id = windowID { return [id] }
        return children.flatMap { $0.windows }
    }

    public var averageChildWeight: Double {
        children.isEmpty ? 1 : children.map(\.weight).reduce(0, +) / Double(children.count)
    }

    public func with(weight: Double) -> Node { Node(kind: kind, weight: weight, children: children) }
    public func with(children: [Node]) -> Node { Node(kind: kind, weight: weight, children: children) }
    public func with(kind: Kind) -> Node { Node(kind: kind, weight: weight, children: children) }

    public func path(of id: WindowID) -> [Int]? {
        if windowID == id { return [] }
        for (index, child) in children.enumerated() {
            if let sub = child.path(of: id) { return [index] + sub }
        }
        return nil
    }

    public func node(at path: [Int]) -> Node? {
        guard let first = path.first else { return self }
        guard children.indices.contains(first) else { return nil }
        return children[first].node(at: Array(path.dropFirst()))
    }

    public func replacingNode(at path: [Int], with replacement: Node) -> Node {
        guard let first = path.first else { return replacement }
        guard children.indices.contains(first) else { return self }
        let updated = children.enumerated().map { index, child in
            index == first ? child.replacingNode(at: Array(path.dropFirst()), with: replacement) : child
        }
        return with(children: updated)
    }
}

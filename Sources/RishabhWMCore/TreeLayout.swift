public struct LayoutSettings: Equatable {
    public let innerGap: Double
    public let outerGap: Double
    public let accordionPadding: Double
    /// ⌥hjkl past the last window wraps around to the opposite edge instead of stopping.
    public let wrapFocus: Bool

    public init(innerGap: Double = 0, outerGap: Double = 0, accordionPadding: Double = 30, wrapFocus: Bool = true) {
        self.innerGap = innerGap
        self.outerGap = outerGap
        self.accordionPadding = accordionPadding
        self.wrapFocus = wrapFocus
    }

    public static let `default` = LayoutSettings()
}

/// Turns a layout tree into concrete frames.
public enum TreeLayout {
    public static func windowRects(_ root: Node, in area: Rect, settings: LayoutSettings) -> [WindowID: Rect] {
        let all = nodeRects(root, in: area.insetBy(settings.outerGap), settings: settings)
        return all.reduce(into: [WindowID: Rect]()) { result, entry in
            if let id = root.node(at: entry.key)?.windowID { result[id] = entry.value }
        }
    }

    /// Frame of every node, keyed by its path from the root.
    public static func nodeRects(_ root: Node, in rect: Rect, settings: LayoutSettings) -> [[Int]: Rect] {
        collect(root, path: [], rect: rect, settings: settings)
    }

    private static func collect(_ node: Node, path: [Int], rect: Rect, settings: LayoutSettings) -> [[Int]: Rect] {
        let own: [[Int]: Rect] = [path: rect]
        guard node.isContainer, !node.children.isEmpty else { return own }
        let rects = childRects(node, in: rect, settings: settings)
        return node.children.indices.reduce(own) { result, index in
            result.merging(
                collect(node.children[index], path: path + [index], rect: rects[index], settings: settings)
            ) { first, _ in first }
        }
    }

    static func childRects(_ container: Node, in rect: Rect, settings: LayoutSettings) -> [Rect] {
        guard let orientation = container.orientation, let layout = container.layout else { return [] }
        switch layout {
        case .tiles: return tiles(container.children, orientation, rect, settings.innerGap)
        case .accordion: return accordion(container.children.count, orientation, rect, settings.accordionPadding)
        }
    }

    private static func tiles(_ children: [Node], _ orientation: Orientation, _ rect: Rect, _ gap: Double) -> [Rect] {
        let count = children.count
        let totalWeight = children.map(\.weight).reduce(0, +)
        let available = max(0, rect.length(along: orientation) - gap * Double(count - 1))
        let lengths = children.map { totalWeight > 0 ? available * $0.weight / totalWeight : available / Double(count) }
        let starts = lengths.indices.map { index in
            lengths[..<index].reduce(0, +) + gap * Double(index)
        }
        return lengths.indices.map { index in
            orientation == .horizontal
                ? Rect(x: rect.x + starts[index], y: rect.y, width: lengths[index], height: rect.height)
                : Rect(x: rect.x, y: rect.y + starts[index], width: rect.width, height: lengths[index])
        }
    }

    private static func accordion(_ count: Int, _ orientation: Orientation, _ rect: Rect, _ padding: Double) -> [Rect] {
        guard count > 1 else { return Array(repeating: rect, count: count) }
        return (0..<count).map { index in
            let lead = index > 0 ? padding : 0
            let trail = index < count - 1 ? padding : 0
            return orientation == .horizontal
                ? Rect(x: rect.x + lead, y: rect.y, width: max(0, rect.width - lead - trail), height: rect.height)
                : Rect(x: rect.x, y: rect.y + lead, width: rect.width, height: max(0, rect.height - lead - trail))
        }
    }
}

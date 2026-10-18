public enum MoveOutcome: Equatable {
    case moved(Node)
    /// The window is already at the outer edge of the tree in that direction.
    case atEdge
    case notFound
}

/// AeroSpace-style tree commands: move, join-with, layout toggles, resize, flatten.
extension Node {
    public func moving(_ id: WindowID, _ direction: Direction) -> MoveOutcome {
        guard let path = path(of: id), !path.isEmpty, let window = node(at: path) else { return .notFound }
        if windows.count < 2 { return .atEdge }
        let orientation = direction.orientation

        for depth in stride(from: path.count - 1, through: 0, by: -1) {
            let ancestorPath = Array(path[0..<depth])
            guard let ancestor = node(at: ancestorPath), ancestor.orientation == orientation else { continue }
            let branch = path[depth]

            if depth == path.count - 1 {
                // Direct parent: swap with a sibling window, or step into a sibling container.
                let neighbor = direction.isForward ? branch + 1 : branch - 1
                guard ancestor.children.indices.contains(neighbor) else { continue }
                if ancestor.children[neighbor].windowID != nil {
                    return .moved(swappingChildren(in: ancestorPath, branch, neighbor))
                }
                let removed = removingWindowRaw(id)
                let siblingPath = ancestorPath + [neighbor > branch ? neighbor - 1 : neighbor]
                guard let sibling = removed.node(at: siblingPath) else { return .notFound }
                let inserted = removed.insertingChild(
                    window.with(weight: sibling.averageChildWeight),
                    intoContainerAt: siblingPath,
                    index: sibling.children.count
                )
                return .moved(inserted.normalized())
            }

            // Higher ancestor: pop the window out next to the branch that contained it.
            let index = direction.isForward ? branch + 1 : branch
            let inserted = removingWindowRaw(id).insertingChild(
                window.with(weight: ancestor.averageChildWeight),
                intoContainerAt: ancestorPath,
                index: index
            )
            return .moved(inserted.normalized())
        }

        if self.orientation == orientation { return .atEdge }

        // No ancestor runs in this direction: wrap the root in a new container that does.
        let rest = removingWindowRaw(id).normalized().with(weight: 1)
        let single = window.with(weight: 1)
        let kids = direction.isForward ? [rest, single] : [single, rest]
        return .moved(Node.container(orientation, .tiles, kids).normalized())
    }

    /// Wraps the window and its neighbor in `direction` into a new container of the opposite orientation.
    public func joining(_ id: WindowID, _ direction: Direction) -> Node? {
        guard let path = path(of: id), let index = path.last else { return nil }
        let parentPath = Array(path.dropLast())
        guard let parent = node(at: parentPath), parent.orientation == direction.orientation else { return nil }
        let neighbor = direction.isForward ? index + 1 : index - 1
        guard parent.children.indices.contains(neighbor) else { return nil }

        let me = parent.children[index]
        let other = parent.children[neighbor]
        if other.isContainer {
            if case .moved(let tree) = moving(id, direction) { return tree }
            return nil
        }
        let pair = direction.isForward
            ? [me.with(weight: 1), other.with(weight: 1)]
            : [other.with(weight: 1), me.with(weight: 1)]
        let joined = Node.container(
            direction.orientation.opposite,
            .tiles,
            pair,
            weight: me.weight + other.weight
        )
        let low = min(index, neighbor)
        let kids = Array(parent.children[..<low]) + [joined] + Array(parent.children[(low + 2)...])
        return replacingNode(at: parentPath, with: parent.with(children: kids)).normalized()
    }

    /// `layout tiles horizontal vertical`: accordion -> tiles, tiles -> flip orientation.
    public func togglingTiles(for id: WindowID) -> Node? {
        updatingParentKind(of: id) { orientation, layout in
            layout == .accordion ? .container(orientation, .tiles) : .container(orientation.opposite, .tiles)
        }
    }

    /// `layout accordion horizontal vertical`: tiles -> accordion, accordion -> flip orientation.
    public func togglingAccordion(for id: WindowID) -> Node? {
        updatingParentKind(of: id) { orientation, layout in
            layout == .tiles ? .container(orientation, .accordion) : .container(orientation.opposite, .accordion)
        }
    }

    private func updatingParentKind(
        of id: WindowID,
        _ transform: (Orientation, ContainerLayout) -> Kind
    ) -> Node? {
        guard let path = path(of: id), !path.isEmpty else { return nil }
        let parentPath = Array(path.dropLast())
        guard let parent = node(at: parentPath),
              case .container(let orientation, let layout) = parent.kind
        else { return nil }
        return replacingNode(at: parentPath, with: parent.with(kind: transform(orientation, layout))).normalized()
    }

    /// Grows (positive delta) or shrinks the window by `delta` points along its parent's orientation.
    public func resizing(_ id: WindowID, by delta: Double, parentLength: Double) -> Node? {
        guard parentLength > 0, let path = path(of: id), let index = path.last else { return nil }
        let parentPath = Array(path.dropLast())
        guard let parent = node(at: parentPath), parent.layout == .tiles, parent.children.count > 1 else {
            return nil
        }
        let total = parent.children.map(\.weight).reduce(0, +)
        let current = parent.children[index].weight
        let others = total - current
        let share = min(0.95, max(0.05, current / total + delta / parentLength))
        let newWeight = share * others / (1 - share)
        let kids = parent.children.enumerated().map { i, child in
            i == index ? child.with(weight: newWeight) : child
        }
        return replacingNode(at: parentPath, with: parent.with(children: kids))
    }

    /// Service-mode `r`: every window side by side in one horizontal row.
    public func flattened() -> Node {
        Node.container(.horizontal, .tiles, windows.map { Node.window($0) })
    }
}

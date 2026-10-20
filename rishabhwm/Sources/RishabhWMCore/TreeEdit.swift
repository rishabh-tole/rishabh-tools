/// Structural edits on the layout tree. Every function returns a new tree.
extension Node {
    /// Removes a window without normalizing, so ancestor paths stay stable for a follow-up insert.
    func removingWindowRaw(_ id: WindowID) -> Node {
        guard isContainer else { return self }
        let kept = children
            .filter { $0.windowID != id }
            .map { $0.removingWindowRaw(id) }
        return with(children: kept)
    }

    func insertingChild(_ child: Node, intoContainerAt path: [Int], index: Int) -> Node {
        guard let target = node(at: path), target.isContainer else { return self }
        let clamped = min(max(0, index), target.children.count)
        let updated = Array(target.children[..<clamped]) + [child] + Array(target.children[clamped...])
        return replacingNode(at: path, with: target.with(children: updated))
    }

    func swappingChildren(in parentPath: [Int], _ i: Int, _ j: Int) -> Node {
        guard let parent = node(at: parentPath),
              parent.children.indices.contains(i), parent.children.indices.contains(j)
        else { return self }
        let swapped = parent.children.indices.map { index -> Node in
            if index == i { return parent.children[j] }
            if index == j { return parent.children[i] }
            return parent.children[index]
        }
        return replacingNode(at: parentPath, with: parent.with(children: swapped))
    }

    public func removingWindow(_ id: WindowID) -> Node {
        removingWindowRaw(id).normalized()
    }

    /// Canonical form:
    /// - empty non-root containers are dropped
    /// - single-child non-root containers are replaced by their child
    /// - a child container with the same orientation and layout as its parent is merged into it
    /// - a root holding exactly one container is replaced by that container
    public func normalized() -> Node {
        var current = self
        for _ in 0..<8 {
            let next = current.normalizedOnce().liftingSingleContainerChild()
            if next == current { break }
            current = next
        }
        return current
    }

    private func normalizedOnce() -> Node {
        guard case .container(let orientation, let layout) = kind else { return self }
        let kids = children
            .map { $0.normalizedOnce() }
            .filter { !($0.isContainer && $0.children.isEmpty) }
            .map { child -> Node in
                guard child.isContainer, child.children.count == 1 else { return child }
                return child.children[0].with(weight: child.weight)
            }
            .flatMap { child -> [Node] in
                guard case .container(let o, let l) = child.kind, o == orientation, l == layout else {
                    return [child]
                }
                let total = child.children.map(\.weight).reduce(0, +)
                guard total > 0 else { return child.children }
                return child.children.map { $0.with(weight: child.weight * $0.weight / total) }
            }
        return with(children: kids)
    }

    private func liftingSingleContainerChild() -> Node {
        guard children.count == 1, let only = children.first, only.isContainer else { return self }
        return only.with(weight: weight)
    }
}

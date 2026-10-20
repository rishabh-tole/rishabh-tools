public struct Workspace: Equatable {
    public let name: String
    public let root: Node
    public let floating: [WindowID]
    /// Window filling the whole monitor (⌥F), drawn above the rest of the workspace.
    public let fullscreen: WindowID?
    public let lastFocused: WindowID?

    public init(name: String, root: Node, floating: [WindowID], fullscreen: WindowID?, lastFocused: WindowID?) {
        self.name = name
        self.root = root
        self.floating = floating
        self.fullscreen = fullscreen
        self.lastFocused = lastFocused
    }

    public static func empty(_ name: String) -> Workspace {
        Workspace(name: name, root: .container(.horizontal), floating: [], fullscreen: nil, lastFocused: nil)
    }

    public var windows: [WindowID] { root.windows + floating }
    public var isEmpty: Bool { windows.isEmpty }
    public func contains(_ id: WindowID) -> Bool { windows.contains(id) }
    public func isFloating(_ id: WindowID) -> Bool { floating.contains(id) }
    public func isTiled(_ id: WindowID) -> Bool { root.path(of: id) != nil }

    public func with(root: Node) -> Workspace {
        Workspace(name: name, root: root, floating: floating, fullscreen: fullscreen, lastFocused: lastFocused)
    }

    public func with(floating: [WindowID]) -> Workspace {
        Workspace(name: name, root: root, floating: floating, fullscreen: fullscreen, lastFocused: lastFocused)
    }

    public func with(fullscreen: WindowID?) -> Workspace {
        Workspace(name: name, root: root, floating: floating, fullscreen: fullscreen, lastFocused: lastFocused)
    }

    public func with(lastFocused: WindowID?) -> Workspace {
        Workspace(name: name, root: root, floating: floating, fullscreen: fullscreen, lastFocused: lastFocused)
    }

    /// Adds a window right after the last focused tiled window (or at the end of the root).
    public func adding(_ id: WindowID, floating isFloating: Bool) -> Workspace {
        guard !contains(id) else { return self }
        if isFloating { return with(floating: floating + [id]) }
        if let anchor = lastFocused, let path = root.path(of: anchor), let index = path.last {
            let parentPath = Array(path.dropLast())
            let weight = root.node(at: parentPath)?.averageChildWeight ?? 1
            let tree = root.insertingChild(.window(id, weight: weight), intoContainerAt: parentPath, index: index + 1)
            return with(root: tree.normalized())
        }
        let tree = root.insertingChild(
            .window(id, weight: root.averageChildWeight),
            intoContainerAt: [],
            index: root.children.count
        )
        return with(root: tree.normalized())
    }

    public func removing(_ id: WindowID) -> Workspace {
        guard contains(id) else { return self }
        let before = windows
        let newRoot = root.removingWindow(id)
        let newFloating = floating.filter { $0 != id }
        let remaining = newRoot.windows + newFloating
        let newLast: WindowID? = {
            guard lastFocused == id else { return lastFocused }
            guard !remaining.isEmpty, let index = before.firstIndex(of: id) else { return nil }
            return remaining[min(max(index - 1, 0), remaining.count - 1)]
        }()
        return Workspace(
            name: name,
            root: newRoot,
            floating: newFloating,
            fullscreen: fullscreen == id ? nil : fullscreen,
            lastFocused: newLast
        )
    }
}

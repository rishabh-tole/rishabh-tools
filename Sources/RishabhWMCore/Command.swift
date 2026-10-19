public enum Command: Equatable {
    case focus(Direction)
    case move(Direction)
    case joinWith(Direction)
    case resize(Double)
    case layoutTiles
    case layoutAccordion
    case fullscreen
    case toggleFloat
    case flatten
    case workspace(String)
    case moveToWorkspace(String)
    case workspaceBackAndForth
    case moveWorkspaceToNextMonitor
    /// Focus the display in that direction (wraps around).
    case focusMonitor(Direction)
    /// Send the focused window to the display in that direction (wraps around); focus follows it.
    case moveToMonitor(Direction)

    /// Commands still allowed while a native-fullscreen app is in front.
    /// Everything else is ignored there, so rishabhwm never touches fullscreen apps.
    public var worksFromFullscreen: Bool {
        switch self {
        case .workspace, .workspaceBackAndForth: return true
        default: return false
        }
    }
}

extension World {
    public func applying(_ command: Command, settings: LayoutSettings = .default) -> World {
        switch command {
        case .focus(let direction): return focusingDirection(direction, settings: settings)
        case .move(let direction): return movingFocused(direction)
        case .joinWith(let direction): return editingFocusedTree { $0.joining($1, direction) }
        case .resize(let delta): return resizingFocused(by: delta, settings: settings)
        case .layoutTiles: return editingFocusedTree { $0.togglingTiles(for: $1) }
        case .layoutAccordion: return editingFocusedTree { $0.togglingAccordion(for: $1) }
        case .flatten: return editingFocusedTree { tree, _ in tree.flattened() }
        case .fullscreen: return togglingFullscreen()
        case .toggleFloat: return togglingFloat()
        case .workspace(let name): return switchingTo(name)
        case .moveToWorkspace(let name): return movingFocused(toWorkspace: name)
        case .workspaceBackAndForth: return previousWorkspace.map { switchingTo($0) } ?? self
        case .moveWorkspaceToNextMonitor: return movingWorkspaceToNextMonitor()
        case .focusMonitor(let direction): return focusingMonitor(direction)
        case .moveToMonitor(let direction): return movingFocused(toMonitor: direction)
        }
    }

    // MARK: - Workspaces

    public func switchingTo(_ name: String) -> World {
        guard names.contains(name) else { return self }
        let current = focusedWorkspaceName
        let target = workspace(name)
        let focus = target.lastFocused ?? target.windows.first
        if let index = monitorIndex(showing: name) {
            guard index != focusedMonitor else { return self }
            return with(focusedMonitor: index, previousWorkspace: current).with(focused: focus)
        }
        let home = homeMonitor(for: name)
        return showing(name, onMonitor: home)
            .with(focusedMonitor: home, previousWorkspace: current)
            .with(focused: focus)
    }

    public func movingFocused(toWorkspace name: String) -> World {
        guard names.contains(name), let id = focused, let from = workspaceName(of: id), from != name else { return self }
        let source = workspace(from)
        let newSource = source.removing(id)
        let newTarget = workspace(name).adding(id, floating: source.isFloating(id)).with(lastFocused: id)
        return replacing(newSource).replacing(newTarget).with(focused: newSource.lastFocused)
    }

    func movingWorkspaceToNextMonitor() -> World {
        guard monitors.count > 1, let free = firstFreeWorkspace() else { return self }
        let next = (focusedMonitor + 1) % monitors.count
        let moving = focusedWorkspaceName
        return showing(moving, onMonitor: next)
            .showing(free, onMonitor: focusedMonitor)
            .with(focusedMonitor: next)
    }

    // MARK: - Tree edits on the focused window

    func movingFocused(_ direction: Direction) -> World {
        guard let id = focused, let name = workspaceName(of: id), let source = monitorIndex(showing: name) else { return self }
        let workspace = self.workspace(name)
        guard workspace.isTiled(id) else { return self }
        switch workspace.root.moving(id, direction) {
        case .moved(let tree): return replacing(workspace.with(root: tree))
        case .notFound: return self
        case .atEdge:
            guard let target = monitorIndex(direction, from: source) else { return self }
            return movingWindow(id, from: name, toMonitor: target)
        }
    }

    func editingFocusedTree(_ edit: (Node, WindowID) -> Node?) -> World {
        guard let id = focused, let name = workspaceName(of: id) else { return self }
        let workspace = self.workspace(name)
        guard workspace.isTiled(id), let tree = edit(workspace.root, id) else { return self }
        return replacing(workspace.with(root: tree))
    }

    func resizingFocused(by delta: Double, settings: LayoutSettings) -> World {
        guard let id = focused, let name = workspaceName(of: id), let index = monitorIndex(showing: name) else { return self }
        let workspace = self.workspace(name)
        guard let path = workspace.root.path(of: id), !path.isEmpty else { return self }
        let parentPath = Array(path.dropLast())
        let area = monitors[index].frame.insetBy(settings.outerGap)
        let rects = TreeLayout.nodeRects(workspace.root, in: area, settings: settings)
        guard let parent = workspace.root.node(at: parentPath), let orientation = parent.orientation,
              let parentRect = rects[parentPath],
              let tree = workspace.root.resizing(id, by: delta, parentLength: parentRect.length(along: orientation))
        else { return self }
        return replacing(workspace.with(root: tree))
    }

    func togglingFullscreen() -> World {
        guard let id = focused, let name = workspaceName(of: id) else { return self }
        let workspace = self.workspace(name)
        return replacing(workspace.with(fullscreen: workspace.fullscreen == id ? nil : id))
    }

    func togglingFloat() -> World {
        guard let id = focused, let name = workspaceName(of: id) else { return self }
        let workspace = self.workspace(name)
        let toggled = workspace.removing(id).adding(id, floating: !workspace.isFloating(id)).with(lastFocused: id)
        return replacing(toggled)
    }
}

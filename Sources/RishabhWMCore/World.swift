public struct Monitor: Equatable {
    public let id: String
    /// Usable area (menu bar and Dock excluded), global top-left coordinates.
    public let frame: Rect
    public let workspace: String

    public init(id: String, frame: Rect, workspace: String) {
        self.id = id
        self.frame = frame
        self.workspace = workspace
    }

    func with(workspace: String) -> Monitor { Monitor(id: id, frame: frame, workspace: workspace) }
}

public struct Screen: Equatable {
    public let id: String
    public let frame: Rect

    public init(id: String, frame: Rect) {
        self.id = id
        self.frame = frame
    }
}

/// Whole window-manager state for the home desktop(s). Pure value: every change returns a new World.
public struct World: Equatable {
    public let names: [String]
    public let workspaces: [String: Workspace]
    public let monitors: [Monitor]
    public let focusedMonitor: Int
    public let focused: WindowID?
    public let previousWorkspace: String?

    public init(
        names: [String],
        workspaces: [String: Workspace],
        monitors: [Monitor],
        focusedMonitor: Int,
        focused: WindowID?,
        previousWorkspace: String?
    ) {
        self.names = names
        self.workspaces = workspaces
        self.monitors = monitors
        self.focusedMonitor = monitors.indices.contains(focusedMonitor) ? focusedMonitor : 0
        self.focused = focused
        self.previousWorkspace = previousWorkspace
    }

    /// Monitor i starts on the i-th workspace name.
    public init(names: [String], screens: [Screen]) {
        let monitors = screens.enumerated().map { index, screen in
            Monitor(id: screen.id, frame: screen.frame, workspace: names[min(index, names.count - 1)])
        }
        self.init(names: names, workspaces: [:], monitors: monitors, focusedMonitor: 0, focused: nil, previousWorkspace: nil)
    }

    public func workspace(_ name: String) -> Workspace { workspaces[name] ?? .empty(name) }

    public func workspaceName(of id: WindowID) -> String? {
        workspaces.first { $0.value.contains(id) }?.key
    }

    public func monitorIndex(showing name: String) -> Int? {
        monitors.firstIndex { $0.workspace == name }
    }

    public func isVisible(_ name: String) -> Bool { monitorIndex(showing: name) != nil }

    public var focusedWorkspaceName: String {
        monitors.indices.contains(focusedMonitor) ? monitors[focusedMonitor].workspace : (names.first ?? "1")
    }

    public var allWindows: [WindowID] { workspaces.values.flatMap { $0.windows } }

    // MARK: - Copy helpers

    func with(
        workspaces: [String: Workspace]? = nil,
        monitors: [Monitor]? = nil,
        focusedMonitor: Int? = nil,
        previousWorkspace: String? = nil
    ) -> World {
        World(
            names: names,
            workspaces: workspaces ?? self.workspaces,
            monitors: monitors ?? self.monitors,
            focusedMonitor: focusedMonitor ?? self.focusedMonitor,
            focused: focused,
            previousWorkspace: previousWorkspace ?? self.previousWorkspace
        )
    }

    func with(focused: WindowID?) -> World {
        World(
            names: names,
            workspaces: workspaces,
            monitors: monitors,
            focusedMonitor: focusedMonitor,
            focused: focused,
            previousWorkspace: previousWorkspace
        )
    }

    func replacing(_ workspace: Workspace) -> World {
        with(workspaces: workspaces.merging([workspace.name: workspace]) { _, new in new })
    }

    func showing(_ name: String, onMonitor index: Int) -> World {
        guard monitors.indices.contains(index) else { return self }
        let updated = monitors.enumerated().map { i, monitor in i == index ? monitor.with(workspace: name) : monitor }
        return with(monitors: updated)
    }

    /// First workspace not on any monitor, preferring empty ones.
    func firstFreeWorkspace() -> String? {
        let hidden = names.filter { !isVisible($0) }
        return hidden.first { workspace($0).isEmpty } ?? hidden.first
    }
}

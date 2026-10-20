/// Which display a workspace is pinned to (`[monitors]` in the config).
public enum MonitorRole: String, CaseIterable, Equatable {
    /// The display with the menu bar (System Settings → Displays → "Main display").
    case main
    /// Any display that is not the main one.
    case secondary
    /// The laptop's own screen.
    case builtin
    /// Any display that is not the laptop screen.
    case external
}

public struct Monitor: Equatable {
    public let id: String
    /// Usable area (menu bar and Dock excluded), global top-left coordinates.
    public let frame: Rect
    public let workspace: String
    public let isMain: Bool
    public let isBuiltin: Bool

    public init(id: String, frame: Rect, workspace: String, isMain: Bool = false, isBuiltin: Bool = false) {
        self.id = id
        self.frame = frame
        self.workspace = workspace
        self.isMain = isMain
        self.isBuiltin = isBuiltin
    }

    func with(workspace: String) -> Monitor {
        Monitor(id: id, frame: frame, workspace: workspace, isMain: isMain, isBuiltin: isBuiltin)
    }

    public func matches(_ role: MonitorRole) -> Bool {
        switch role {
        case .main: return isMain
        case .secondary: return !isMain
        case .builtin: return isBuiltin
        case .external: return !isBuiltin
        }
    }
}

public struct Screen: Equatable {
    public let id: String
    public let frame: Rect
    public let isMain: Bool
    public let isBuiltin: Bool

    public init(id: String, frame: Rect, isMain: Bool = false, isBuiltin: Bool = false) {
        self.id = id
        self.frame = frame
        self.isMain = isMain
        self.isBuiltin = isBuiltin
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
    /// Workspaces pinned to a display role. They open there whenever such a display is connected.
    public let assignments: [String: MonitorRole]

    public init(
        names: [String],
        workspaces: [String: Workspace],
        monitors: [Monitor],
        focusedMonitor: Int,
        focused: WindowID?,
        previousWorkspace: String?,
        assignments: [String: MonitorRole] = [:]
    ) {
        self.names = names
        self.workspaces = workspaces
        self.monitors = monitors
        self.focusedMonitor = monitors.indices.contains(focusedMonitor) ? focusedMonitor : 0
        self.focused = focused
        self.previousWorkspace = previousWorkspace
        self.assignments = assignments
    }

    /// The main display starts on the first workspace name, the others on the next ones (left to right).
    public init(names: [String], screens: [Screen]) {
        let ranked = screens.indices.sorted { (screens[$0].isMain ? 0 : 1, $0) < (screens[$1].isMain ? 0 : 1, $1) }
        let monitors = screens.enumerated().map { index, screen in
            let rank = ranked.firstIndex(of: index) ?? index
            return Monitor(
                id: screen.id,
                frame: screen.frame,
                workspace: names[min(rank, names.count - 1)],
                isMain: screen.isMain,
                isBuiltin: screen.isBuiltin
            )
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

    /// Monitor a hidden workspace should appear on: its pinned display if connected, else the focused one.
    public func homeMonitor(for name: String) -> Int {
        guard let role = assignments[name], let index = monitors.firstIndex(where: { $0.matches(role) }) else {
            return focusedMonitor
        }
        return index
    }

    public func with(assignments: [String: MonitorRole]) -> World {
        World(
            names: names,
            workspaces: workspaces,
            monitors: monitors,
            focusedMonitor: focusedMonitor,
            focused: focused,
            previousWorkspace: previousWorkspace,
            assignments: assignments
        )
    }

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
            previousWorkspace: previousWorkspace ?? self.previousWorkspace,
            assignments: assignments
        )
    }

    func with(focused: WindowID?) -> World {
        World(
            names: names,
            workspaces: workspaces,
            monitors: monitors,
            focusedMonitor: focusedMonitor,
            focused: focused,
            previousWorkspace: previousWorkspace,
            assignments: assignments
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

public enum Placement: Equatable {
    case tiled(Rect)
    /// Visible floating window: left wherever the user put it.
    case floating
    /// On a workspace that no monitor shows: parked off-screen.
    case hidden
}

extension World {
    /// Frames of tiled windows on visible workspaces (⌥F fullscreen windows cover the monitor).
    public func tiledRects(settings: LayoutSettings) -> [WindowID: Rect] {
        monitors.reduce(into: [WindowID: Rect]()) { result, monitor in
            let workspace = self.workspace(monitor.workspace)
            let rects = TreeLayout.windowRects(workspace.root, in: monitor.frame, settings: settings)
            result.merge(rects) { _, new in new }
            if let full = workspace.fullscreen, workspace.isTiled(full) {
                result[full] = monitor.frame
            }
        }
    }

    public func placements(settings: LayoutSettings) -> [WindowID: Placement] {
        let rects = tiledRects(settings: settings)
        return workspaces.values.reduce(into: [WindowID: Placement]()) { result, workspace in
            let visible = isVisible(workspace.name)
            for id in workspace.root.windows {
                result[id] = visible ? rects[id].map(Placement.tiled) ?? .hidden : .hidden
            }
            for id in workspace.floating {
                result[id] = visible ? .floating : .hidden
            }
        }
    }
}

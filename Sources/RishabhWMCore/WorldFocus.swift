/// Directional focus and display-to-display commands.
extension World {
    // MARK: - ⌥hjkl

    /// Focus the neighbor in `direction`. Past the last window it crosses to the next display, and
    /// past the last display it wraps around to the opposite edge (when `settings.wrapFocus`).
    /// An ⌥F fullscreen window stays fullscreen: focus just cycles through the workspace's windows.
    func focusingDirection(_ direction: Direction, settings: LayoutSettings) -> World {
        let workspace = self.workspace(focusedWorkspaceName)
        let rects = tiledRects(settings: settings)
        if let id = focused, workspace.isTiled(id),
           let target = neighbor(of: id, in: workspace, direction, rects: rects) {
            return focusingWindow(target)
        }
        let origin = focused.flatMap { rects[$0] }
        if let index = monitorIndex(direction, from: focusedMonitor) {
            return focusing(monitor: index, near: origin, rects: rects)
        }
        guard settings.wrapFocus else { return self }
        return wrappingFocus(direction, from: origin, rects: rects)
    }

    private func neighbor(of id: WindowID, in workspace: Workspace, _ direction: Direction, rects: [WindowID: Rect]) -> WindowID? {
        guard workspace.fullscreen != nil else { return workspace.root.neighborWindow(of: id, direction, rects: rects) }
        let order = workspace.root.windows
        guard let index = order.firstIndex(of: id) else { return nil }
        let next = direction.isForward ? index + 1 : index - 1
        return order.indices.contains(next) ? order[next] : nil
    }

    private func wrappingFocus(_ direction: Direction, from origin: Rect?, rects: [WindowID: Rect]) -> World {
        guard let index = wrappedMonitorIndex(direction, from: focusedMonitor) else { return self }
        let workspace = self.workspace(monitors[index].workspace)
        let target: WindowID?
        if workspace.fullscreen != nil, index == focusedMonitor {
            target = direction.isForward ? workspace.root.windows.first : workspace.root.windows.last
        } else if let full = workspace.fullscreen {
            target = workspace.lastFocused ?? full
        } else {
            let candidates = workspace.root.windows.isEmpty ? workspace.windows : workspace.root.windows
            target = Navigation.edgeWindow(candidates, enteringFrom: direction, near: origin, rects: rects)
                ?? workspace.lastFocused ?? candidates.first
        }
        guard index != focusedMonitor else { return target.map { focusingWindow($0) } ?? self }
        let moved = with(focusedMonitor: index).with(focused: target)
        return target.map { moved.replacing(workspace.with(lastFocused: $0)) } ?? moved
    }

    /// The display at the far end of `index`'s row (or column) opposite to `direction`: where focus
    /// lands after wrapping. Displays above or below the row are never picked for ⌥h / ⌥l.
    func wrappedMonitorIndex(_ direction: Direction, from index: Int) -> Int? {
        let frames = monitors.map(\.frame)
        guard frames.indices.contains(index) else { return nil }
        let origin = frames[index]
        let horizontal = direction.orientation == .horizontal
        let inLine = frames.indices.filter { candidate in
            let frame = frames[candidate]
            return horizontal
                ? frame.minY < origin.maxY && origin.minY < frame.maxY
                : frame.minX < origin.maxX && origin.minX < frame.maxX
        }
        let position = { (candidate: Int) in horizontal ? frames[candidate].midX : frames[candidate].midY }
        return direction.isForward
            ? inLine.min { position($0) < position($1) }
            : inLine.max { position($0) < position($1) }
    }

    /// Display for ⌥[ / ⌥]: the next one in `direction`, else wrap around the row, else (displays
    /// stacked the other way) simply the next / previous one. Nil with a single display.
    func monitorIndexWrapping(_ direction: Direction, from index: Int) -> Int? {
        guard monitors.count > 1, monitors.indices.contains(index) else { return nil }
        if let next = monitorIndex(direction, from: index) { return next }
        if let wrapped = wrappedMonitorIndex(direction, from: index), wrapped != index { return wrapped }
        let step = direction.isForward ? 1 : monitors.count - 1
        return (index + step) % monitors.count
    }

    /// Moves focus onto another display, picking the window nearest `origin` (or the one last used).
    /// Keeps ⌥Tab history untouched: both workspaces stay visible.
    private func focusing(monitor index: Int, near origin: Rect?, rects: [WindowID: Rect]) -> World {
        let other = self.workspace(monitors[index].workspace)
        let pick: WindowID? = other.fullscreen != nil
            ? other.lastFocused ?? other.fullscreen
            : Navigation.closest(other.root.windows, to: origin, rects: rects) ?? other.lastFocused ?? other.windows.first
        let moved = with(focusedMonitor: index).with(focused: pick)
        guard let pick else { return moved }
        return moved.replacing(other.with(lastFocused: pick))
    }

    // MARK: - Displays

    /// ⌥[ / ⌥]: lands on the window last used there.
    func focusingMonitor(_ direction: Direction) -> World {
        guard let index = monitorIndexWrapping(direction, from: focusedMonitor) else { return self }
        return focusing(monitor: index, near: nil, rects: [:])
    }

    func movingFocused(toMonitor direction: Direction) -> World {
        guard let id = focused, let name = workspaceName(of: id), let source = monitorIndex(showing: name),
              let target = monitorIndexWrapping(direction, from: source)
        else { return self }
        return movingWindow(id, from: name, toMonitor: target)
    }

    /// Moves a window onto the workspace shown on `target`, keeping it floating / ⌥F fullscreen.
    func movingWindow(_ id: WindowID, from name: String, toMonitor target: Int) -> World {
        let source = workspace(name)
        let destinationName = monitors[target].workspace
        guard destinationName != name else { return self }
        let added = workspace(destinationName).adding(id, floating: source.isFloating(id)).with(lastFocused: id)
        let destination = source.fullscreen == id ? added.with(fullscreen: id) : added
        return replacing(source.removing(id))
            .replacing(destination)
            .with(focusedMonitor: target)
            .with(focused: id)
    }

    func monitorIndex(_ direction: Direction, from index: Int) -> Int? {
        guard monitors.indices.contains(index) else { return nil }
        return Navigation.nearest(direction, from: monitors[index].frame, among: monitors.map(\.frame))
    }
}

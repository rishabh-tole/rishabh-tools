/// Window lifecycle and monitor changes.
extension World {
    /// Adds a new window to `target` (validated) or to the focused monitor's workspace.
    public func addingWindow(_ id: WindowID, toWorkspace target: String?, floating: Bool) -> World {
        guard workspaceName(of: id) == nil else { return self }
        let name = target.flatMap { names.contains($0) ? $0 : nil } ?? focusedWorkspaceName
        let workspace = self.workspace(name).adding(id, floating: floating).with(lastFocused: id)
        return replacing(workspace)
    }

    public func removingWindow(_ id: WindowID) -> World {
        guard let name = workspaceName(of: id) else { return self }
        let workspace = self.workspace(name).removing(id)
        let updated = replacing(workspace)
        guard focused == id else { return updated }
        return updated.with(focused: isVisible(name) ? workspace.lastFocused : nil)
    }

    /// Focus moved to `id` (by the user or macOS). If its workspace is hidden, bring it up on the
    /// focused monitor, like AeroSpace does when you ⌘Tab into a window on another workspace.
    public func focusingWindow(_ id: WindowID) -> World {
        guard let name = workspaceName(of: id) else { return self }
        let current = focusedWorkspaceName
        let shown = isVisible(name) ? self : showing(name, onMonitor: homeMonitor(for: name))
        guard let monitor = shown.monitorIndex(showing: name) else { return self }
        let previous = name == current ? previousWorkspace : current
        return shown
            .replacing(shown.workspace(name).with(lastFocused: id))
            .with(focusedMonitor: monitor, previousWorkspace: previous)
            .with(focused: id)
    }

    public func updatingMonitors(_ screens: [Screen]) -> World {
        guard !screens.isEmpty else { return self }
        let oldByID = Dictionary(monitors.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let kept: [String?] = screens.map { oldByID[$0.id]?.workspace }
        let assigned = screens.indices.reduce(into: [String]()) { result, index in
            if let keep = kept[index], !result.contains(keep) {
                result.append(keep)
                return
            }
            let taken = Set(result + kept.compactMap { $0 })
            let free = names.first { !taken.contains($0) && workspace($0).isEmpty }
                ?? names.first { !taken.contains($0) }
                ?? names[0]
            result.append(free)
        }
        let newMonitors = screens.indices.map { index in
            Monitor(
                id: screens[index].id,
                frame: screens[index].frame,
                workspace: assigned[index],
                isMain: screens[index].isMain,
                isBuiltin: screens[index].isBuiltin
            )
        }
        let focusedID = monitors.indices.contains(focusedMonitor) ? monitors[focusedMonitor].id : nil
        let newFocus = newMonitors.firstIndex { $0.id == focusedID } ?? 0
        let world = with(monitors: newMonitors, focusedMonitor: newFocus)
        guard let id = focused, let name = world.workspaceName(of: id), world.isVisible(name) else {
            return world.with(focused: nil)
        }
        return world
    }
}

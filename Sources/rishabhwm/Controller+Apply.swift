import AppKit
import RishabhWMCore

/// Pushing the World onto real windows.
extension Controller {
    func scheduleLayout() {
        guard !layoutPending else { return }
        layoutPending = true
        DispatchQueue.main.async { [weak self] in
            self?.layoutPending = false
            self?.applyLayout()
        }
    }

    func scheduleRefresh() {
        guard !refreshPending else { return }
        refreshPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.refreshPending = false
            self?.refresh()
        }
    }

    /// Pushes every placement to its window. Windows coming on screen go first (the focused one
    /// first of all) and windows being hidden last, so a switch never flashes an empty desktop.
    func applyLayout() {
        let placements = world.placements(settings: config.layout)
        let ordered = placements.sorted { applyOrder($0.key, $0.value) < applyOrder($1.key, $1.value) }
        for (id, placement) in ordered {
            guard let window = windows[id] else { continue }
            apply(placement, to: window)
        }
        statusBar.show(world, serviceMode: serviceMode)
    }

    private func applyOrder(_ id: WindowID, _ placement: Placement) -> Int {
        if placement == .hidden { return 2 }
        return id == world.focused ? 0 : 1
    }

    private func apply(_ placement: Placement, to window: TrackedWindow) {
        let id = window.id
        switch placement {
        case .tiled(let rect):
            let target = rect.rounded
            let parkedFrame = parked.removeValue(forKey: id)
            let previous = parkedFrame ?? applied[id]
            guard parkedFrame != nil || previous?.isClose(to: target) != true else { return }
            applied[id] = target
            setFrame(window, target, from: previous)

        case .floating:
            applied[id] = nil
            guard let parkedFrame = parked.removeValue(forKey: id) else { return }
            setFrame(window, floatingFrames[id] ?? parkedFrame, from: parkedFrame)

        case .hidden:
            guard parked[id] == nil else { return }
            let floating = world.workspaceName(of: id).map { world.workspace($0).isFloating(id) } ?? false
            // Tiled windows are where we put them; only floating ones need asking.
            let known = floating ? nil : applied[id]
            let current = known ?? AX.frame(window.element) ?? Rect(x: 0, y: 0, width: 800, height: 600)
            if floating { floatingFrames[id] = current }
            let origin = Screens.parkingOrigin(for: current, size: current, in: screens)
            parked[id] = current
            applied[id] = nil
            setFrame(window, Rect(x: origin.x, y: origin.y, width: current.width, height: current.height), from: current)
        }
    }

    /// Moves a window on its app's queue. When the size is unchanged (always the case when parking
    /// and unparking) only the position is set: one AX call instead of four, and the app doesn't
    /// re-layout, so there's no redraw tearing.
    func setFrame(_ window: TrackedWindow, _ frame: Rect, from previous: Rect?) {
        let element = window.element
        let app = appElement(window.pid)
        let keepsSize = previous.map { abs($0.width - frame.width) < 1 && abs($0.height - frame.height) < 1 } ?? false
        ignoreGeometryUntil[window.id] = Date().addingTimeInterval(0.5)
        mover.move(window) {
            if keepsSize {
                AX.setPosition(element, x: frame.x, y: frame.y)
            } else {
                AX.setFrame(element, app: app, frame)
            }
        }
    }

    /// Gives keyboard focus to the World's focused window, or to the display's anchor when the
    /// workspace is empty. Either way macOS switches back to the home desktop if needed.
    func applyFocus(extendSuppression: Bool = true) {
        if extendSuppression { suppressFocusSwitchUntil = Date().addingTimeInterval(0.4) }
        let workspace = world.workspace(world.focusedWorkspaceName)
        let target = world.focused ?? workspace.lastFocused ?? workspace.windows.first
        guard let id = target, let window = windows[id] else {
            anchors.focus(monitor: world.focusedMonitor)
            return
        }
        if world.focused != id { world = world.focusingWindow(id) }
        if !SkyLight.focus(pid: window.pid, window: id) {
            NSRunningApplication(processIdentifier: window.pid)?.activate()
        }
        // Raise once the app has moved the window into place.
        let element = window.element
        mover.after(window.pid) { AX.raise(element) }
    }

    /// Re-scans every app's windows on the home desktop: adopts new ones, drops gone ones
    /// (closed, minimized, hidden app, moved to fullscreen or another Space).
    func refresh() {
        guard started, Spaces.isOnHome() else { return }
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ownPID
        }
        apps.forEach(observe)
        let found = apps.filter { !$0.isHidden }.flatMap { app -> [(WindowID, AXUIElement, pid_t)] in
            let pid = app.processIdentifier
            return AX.windows(ofApp: appElement(pid)).compactMap { element in
                guard AX.isManageable(element), let id = AX.windowID(element), Spaces.isOnHome(window: id) else { return nil }
                return (id, element, pid)
            }
        }
        let foundIDs = Set(found.map(\.0))
        windows.keys.filter { !foundIDs.contains($0) }.forEach { forget($0, refocus: false) }
        found.filter { windows[$0.0] == nil }.forEach { adopt($0.1, pid: $0.2) }
        scheduleLayout()
    }

    /// Puts every parked window back on screen. Runs on quit so nothing is left stranded.
    func restoreAll() {
        mover.drain()
        guard let main = screens.first?.visible else { return }
        let fallback = main.insetBy(60)
        for id in parked.keys {
            guard let window = windows[id] else { continue }
            AX.setFrame(window.element, app: appElement(window.pid), floatingFrames[id] ?? fallback)
        }
        parked.removeAll()
    }
}

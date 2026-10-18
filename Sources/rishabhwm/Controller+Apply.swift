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

    func applyLayout() {
        let placements = world.placements(settings: config.layout)
        for (id, placement) in placements {
            guard let window = windows[id] else { continue }
            apply(placement, to: window)
        }
        statusBar.show(world, serviceMode: serviceMode)
    }

    private func apply(_ placement: Placement, to window: TrackedWindow) {
        let id = window.id
        switch placement {
        case .tiled(let rect):
            let target = rect.rounded
            let wasParked = parked.remove(id) != nil
            guard wasParked || applied[id]?.isClose(to: target) != true else { return }
            AX.setFrame(window.element, app: appElement(window.pid), target)
            applied[id] = target

        case .floating:
            applied[id] = nil
            guard parked.remove(id) != nil else { return }
            if let frame = floatingFrames[id] {
                AX.setFrame(window.element, app: appElement(window.pid), frame)
            }

        case .hidden:
            guard !parked.contains(id) else { return }
            let current = AX.frame(window.element) ?? applied[id] ?? Rect(x: 0, y: 0, width: 800, height: 600)
            if let name = world.workspaceName(of: id), world.workspace(name).isFloating(id) {
                floatingFrames[id] = current
            }
            let origin = Screens.parkingOrigin(for: current, size: current, in: screens)
            AX.setPosition(window.element, x: origin.x, y: origin.y)
            parked.insert(id)
            applied[id] = nil
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
        AX.raise(window.element)
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
        guard let main = screens.first?.visible else { return }
        let fallback = main.insetBy(60)
        for id in parked {
            guard let window = windows[id] else { continue }
            AX.setFrame(window.element, app: appElement(window.pid), floatingFrames[id] ?? fallback)
        }
        parked.removeAll()
    }
}

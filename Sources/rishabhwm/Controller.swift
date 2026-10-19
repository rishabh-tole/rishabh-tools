import AppKit
import RishabhWMCore

struct TrackedWindow {
    let id: WindowID
    let element: AXUIElement
    let pid: pid_t
    let bundleID: String?
}

/// Owns the pure `World` and keeps the real windows in sync with it.
///
/// Fullscreen rule: rishabhwm only manages the home desktop of each display. Native-fullscreen
/// windows and other Spaces are never tracked, moved or hidden. From a fullscreen Space only
/// workspace switches work, and they pull you back to the home desktop.
final class Controller {
    var world: World
    var config: Config = .empty
    var screens: [ScreenInfo]
    var windows: [WindowID: TrackedWindow] = [:]
    var observers: [pid_t: AppObserver] = [:]
    /// Last frame we set for each tiled window, to skip redundant AX calls.
    var applied: [WindowID: Rect] = [:]
    var parked: Set<WindowID> = []
    var floatingFrames: [WindowID: Rect] = [:]
    var lastSnap: [WindowID: Date] = [:]
    var serviceMode = false
    var layoutPending = false
    var refreshPending = false
    /// After we move focus ourselves, ignore macOS briefly focusing a window on a hidden workspace.
    var suppressFocusSwitchUntil = Date.distantPast
    var started = false

    let anchors = Anchors()
    let ownPID = ProcessInfo.processInfo.processIdentifier
    lazy var statusBar = StatusBar(
        onReload: { [weak self] in self?.reloadConfig() },
        onSettings: { [weak self] in self?.settingsWindow.show() },
        onQuit: { [weak self] in self?.quit() }
    )

    lazy var settingsWindow = SettingsWindow(
        current: { [weak self] in self?.config ?? .empty },
        onSave: { [weak self] config in
            guard let self else { return .success(()) }
            return ConfigStore.save(config).flatMap { self.reloadConfig() }.map { self.refresh() }
        }
    )

    init() {
        screens = Screens.current()
        world = World(names: Keymap.workspaceNames, screens: Screens.worldScreens(screens))
    }

    func showWaitingForPermission() {
        statusBar.show(world, serviceMode: false, trusted: false)
    }

    func start() {
        guard !started else { return }
        started = true
        Log.info("starting (SkyLight \(SkyLight.isAvailable ? "available" : "missing"), \(screens.count) display(s))")
        reloadConfig()
        HotKeys.shared.install()
        bindMain()
        observeSystem()
        NSWorkspace.shared.runningApplications.forEach(observe)
        if Spaces.isOnHome() { anchors.rebuild() }
        refresh()
        syncFocusFromSystem()
        applyLayout()
    }

    // MARK: - System notifications

    private func observeSystem() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.observe(app)
            self?.scheduleRefresh()
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.removeApp(app.processIdentifier)
        }
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleFocusChange()
        }
        center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSpaceChange()
        }
        for name in [NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.scheduleRefresh() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleScreensChanged()
        }
    }

    func observe(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != ownPID, observers[pid] == nil else { return }
        observers[pid] = AppObserver(app: app) { [weak self] pid, event in self?.handle(pid, event) }
    }

    private func removeApp(_ pid: pid_t) {
        windows.values.filter { $0.pid == pid }.forEach { forget($0.id, refocus: true) }
        observers[pid] = nil
    }

    // MARK: - Window events

    private func handle(_ pid: pid_t, _ event: WindowEvent) {
        switch event {
        case .created(let element):
            adopt(element, pid: pid)
        case .focusChanged:
            handleFocusChange()
        case .destroyed(let id), .minimized(let id):
            forget(id, refocus: true)
        case .geometryChanged(let id):
            handleGeometryChange(id)
        }
    }

    func handleFocusChange() {
        guard started, Spaces.isOnHome(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ownPID,
              let element = AX.focusedWindow(ofApp: appElement(app.processIdentifier)),
              let id = AX.windowID(element)
        else { return }
        if windows[id] == nil { adopt(element, pid: app.processIdentifier) }
        guard windows[id] != nil, let name = world.workspaceName(of: id) else { return }
        if !world.isVisible(name), Date() < suppressFocusSwitchUntil {
            Log.debug("ignoring stray focus to hidden workspace \(name)")
            applyFocus(extendSuppression: false)
            return
        }
        let before = world
        world = world.focusingWindow(id)
        if world != before { scheduleLayout() }
    }

    private func handleSpaceChange() {
        guard started else { return }
        if Spaces.isOnHome() {
            if !anchors.isBuilt { anchors.rebuild() }
            refresh()
            handleFocusChange()
        } else {
            // Left the home desktop: let go of anything that just turned native fullscreen.
            windows.values.filter { AX.isFullscreen($0.element) }.forEach { forget($0.id, refocus: false) }
        }
        statusBar.show(world, serviceMode: serviceMode)
    }

    private func handleScreensChanged() {
        screens = Screens.current()
        world = world.updatingMonitors(Screens.worldScreens(screens))
        if Spaces.isOnHome() { anchors.rebuild() }
        applied.removeAll()
        scheduleLayout()
    }

    private func handleGeometryChange(_ id: WindowID) {
        guard let window = windows[id] else { return }
        if AX.isFullscreen(window.element) {
            forget(id, refocus: false)
            return
        }
        guard applied[id] != nil, !parked.contains(id) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.snapBack(id) }
    }

    /// Tiled windows dragged or resized by hand snap back once the mouse is released.
    private func snapBack(_ id: WindowID) {
        guard let window = windows[id], let target = applied[id], !parked.contains(id) else { return }
        if NSEvent.pressedMouseButtons != 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.snapBack(id) }
            return
        }
        guard let actual = AX.frame(window.element), !actual.isClose(to: target, tolerance: 2) else { return }
        // Windows with a minimum size can't take the frame; don't fight them in a loop.
        if let last = lastSnap[id], Date().timeIntervalSince(last) < 1 { return }
        lastSnap[id] = Date()
        AX.setFrame(window.element, app: appElement(window.pid), target)
    }

    // MARK: - Tracking

    func appElement(_ pid: pid_t) -> AXUIElement { observers[pid]?.app ?? AX.app(pid) }

    @discardableResult
    func adopt(_ element: AXUIElement, pid: pid_t) -> Bool {
        guard pid != ownPID, let id = AX.windowID(element), windows[id] == nil,
              AX.isManageable(element), Spaces.isOnHome(window: id),
              SkyLight.isAvailable || Spaces.isOnHome()
        else { return false }
        let bundleID = observers[pid]?.bundleID ?? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        windows[id] = TrackedWindow(id: id, element: element, pid: pid, bundleID: bundleID)
        observers[pid]?.watch(element, id: id)
        let target = bundleID.flatMap { config.appWorkspaces[$0] }
        let floating = bundleID.map { config.floatingApps.contains($0) } ?? false
        world = world.addingWindow(id, toWorkspace: target, floating: floating)
        Log.debug("adopted \(id) \(bundleID ?? "?") -> \(world.workspaceName(of: id) ?? "?")")
        scheduleLayout()
        return true
    }

    func forget(_ id: WindowID, refocus: Bool) {
        guard let window = windows[id] else { return }
        observers[window.pid]?.unwatch(id)
        windows[id] = nil
        applied[id] = nil
        parked.remove(id)
        floatingFrames[id] = nil
        lastSnap[id] = nil
        let wasFocused = world.focused == id
        world = world.removingWindow(id)
        scheduleLayout()
        if refocus, wasFocused, Spaces.isOnHome() {
            DispatchQueue.main.async { [weak self] in self?.applyFocus() }
        }
    }

    func syncFocusFromSystem() {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ownPID,
              let element = AX.focusedWindow(ofApp: appElement(app.processIdentifier)),
              let id = AX.windowID(element), windows[id] != nil
        else { return }
        world = world.focusingWindow(id)
    }
}

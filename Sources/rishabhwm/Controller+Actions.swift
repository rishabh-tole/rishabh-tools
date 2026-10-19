import AppKit
import RishabhWMCore

/// Hotkey handling and modes.
extension Controller {
    func bindMain() {
        serviceMode = false
        HotKeys.shared.set(Keymap.main) { [weak self] in self?.perform($0) }
        statusBar.show(world, serviceMode: false)
    }

    private func bindService() {
        serviceMode = true
        HotKeys.shared.set(Keymap.service) { [weak self] in self?.perform($0) }
        statusBar.show(world, serviceMode: true)
    }

    private func perform(_ binding: Binding) {
        Log.debug("key \(binding.combo.label)")
        switch binding.action {
        case .command(let command):
            run(command)
        case .enterServiceMode:
            bindService()
        case .reloadConfig:
            reloadConfig()
            refresh()
        case .closeAllButCurrent:
            closeAllButCurrent()
        }
        if binding.exitsServiceMode { bindMain() }
    }

    private func run(_ command: Command) {
        let onHome = Spaces.isOnHome()
        // In a fullscreen app only workspace switches do anything (and they take you home).
        guard onHome || command.worksFromFullscreen else { return }
        if onHome { syncFocusFromSystem() }
        let before = world
        world = world.applying(command, settings: config.layout)
        carryFloatingAcrossDisplays(from: before)
        applyLayout()
        let focusMoved = before.focused != world.focused || before.focusedMonitor != world.focusedMonitor
        if !onHome || focusMoved || command == .fullscreen {
            applyFocus()
        }
    }

    /// Floating windows aren't laid out, so a floating window sent to another display is moved
    /// there by hand, keeping its relative spot.
    private func carryFloatingAcrossDisplays(from before: World) {
        guard let id = world.focused, let window = windows[id],
              let name = world.workspaceName(of: id), world.workspace(name).isFloating(id),
              let oldName = before.workspaceName(of: id),
              let from = before.monitorIndex(showing: oldName), let to = world.monitorIndex(showing: name),
              before.monitors[from].id != world.monitors[to].id,
              let frame = AX.frame(window.element)
        else { return }
        let target = frame.moved(from: before.monitors[from].frame, to: world.monitors[to].frame).rounded
        AX.setFrame(window.element, app: appElement(window.pid), target)
    }

    private func closeAllButCurrent() {
        guard Spaces.isOnHome() else { return }
        world.workspace(world.focusedWorkspaceName).windows
            .filter { $0 != world.focused }
            .compactMap { windows[$0] }
            .forEach { AX.close($0.element) }
    }

    @discardableResult
    func reloadConfig() -> Result<Void, ConfigError> {
        switch ConfigStore.load() {
        case .success(let loaded):
            config = loaded
            world = world.with(assignments: loaded.monitorAssignments)
            statusBar.showError(nil)
            applied.removeAll()
            scheduleLayout()
            Log.info("config loaded: \(loaded.appWorkspaces.count) app rule(s)")
            return .success(())
        case .failure(let error):
            statusBar.showError(error.description)
            Log.error(error.description)
            return .failure(error)
        }
    }

    func quit() {
        restoreAll()
        exit(0)
    }
}

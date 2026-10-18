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
        applyLayout()
        let focusMoved = before.focused != world.focused || before.focusedMonitor != world.focusedMonitor
        if !onHome || focusMoved || command == .fullscreen {
            applyFocus()
        }
    }

    private func closeAllButCurrent() {
        guard Spaces.isOnHome() else { return }
        world.workspace(world.focusedWorkspaceName).windows
            .filter { $0 != world.focused }
            .compactMap { windows[$0] }
            .forEach { AX.close($0.element) }
    }

    func reloadConfig() {
        switch ConfigStore.load() {
        case .success(let loaded):
            config = loaded
            statusBar.showError(nil)
            applied.removeAll()
            scheduleLayout()
            Log.info("config loaded: \(loaded.appWorkspaces.count) app rule(s)")
        case .failure(let error):
            statusBar.showError(error.description)
            Log.error(error.description)
        }
    }

    func quit() {
        restoreAll()
        exit(0)
    }
}

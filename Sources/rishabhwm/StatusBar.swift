import AppKit
import RishabhWMCore

/// Menu bar item showing the visible workspace(s), e.g. "C" or "C · 2" (focused display first).
final class StatusBar: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onReload: () -> Void
    private let onQuit: () -> Void
    private let errorItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init(onReload: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onReload = onReload
        self.onQuit = onQuit
        super.init()
        let menu = NSMenu()
        errorItem.isHidden = true
        menu.addItem(errorItem)
        menu.addItem(withTitle: "Reload Config", action: #selector(reload), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "Edit Config…", action: #selector(editConfig), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit rishabhwm", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        item.button?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
    }

    func show(_ world: World, serviceMode: Bool, trusted: Bool = true) {
        guard trusted else {
            item.button?.title = "⚠︎ wm"
            return
        }
        let order = [world.focusedMonitor] + world.monitors.indices.filter { $0 != world.focusedMonitor }
        let names = order.filter { world.monitors.indices.contains($0) }.map { world.monitors[$0].workspace }
        item.button?.title = (serviceMode ? "⚙︎ " : "") + names.joined(separator: " · ")
    }

    func showError(_ message: String?) {
        errorItem.title = message.map { "⚠︎ \($0)" } ?? ""
        errorItem.isHidden = message == nil
    }

    @objc private func reload() { onReload() }
    @objc private func quit() { onQuit() }
    @objc private func editConfig() { NSWorkspace.shared.open(ConfigStore.url) }
}

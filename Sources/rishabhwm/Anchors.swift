import AppKit

/// Invisible 1x1 windows living on each display's home desktop. Focusing one pulls macOS back to
/// the home desktop (out of a fullscreen app) even when the target workspace has no windows,
/// and takes keyboard focus away from windows that were just hidden.
final class Anchors {
    private final class AnchorWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    private var windows: [NSWindow] = []

    var isBuilt: Bool { !windows.isEmpty }

    /// Must run while the home desktop is active, so the anchors land on it.
    func rebuild() {
        windows.forEach { $0.close() }
        windows = Screens.sortedNSScreens().map { screen in
            let window = AnchorWindow(
                contentRect: NSRect(x: screen.frame.minX, y: screen.frame.minY, width: 1, height: 1),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.ignoresCycle]
            window.orderFrontRegardless()
            return window
        }
    }

    func focus(monitor index: Int) {
        guard windows.indices.contains(index) else { return }
        let window = windows[index]
        SkyLight.focus(pid: ProcessInfo.processInfo.processIdentifier, window: UInt32(window.windowNumber))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func owns(windowNumber: Int) -> Bool { windows.contains { $0.windowNumber == windowNumber } }
}

extension Screens {
    /// NSScreens in the same left-to-right order as `Screens.current()`.
    static func sortedNSScreens() -> [NSScreen] {
        NSScreen.screens.sorted {
            ($0.frame.minX, -$0.frame.maxY) < ($1.frame.minX, -$1.frame.maxY)
        }
    }
}

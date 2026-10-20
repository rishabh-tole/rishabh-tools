import AppKit

/// Menu bar item: how to use it, which optional encoders were found, log and quit.
final class StatusBar: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private static let log = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/rishabhfc.log")

    init(binaries: Binaries) {
        super.init()
        item.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle", accessibilityDescription: "rishabhfc")
        let menu = NSMenu()
        [
            "Drag a file, then tap:",
            "  ⇧ Shift — convert",
            "  ⌘ Command — tools",
            "  ⌃ Control — file actions",
        ].forEach { menu.addItem(info($0)) }
        menu.addItem(.separator())
        menu.addItem(info(binaries.ffmpeg == nil ? "ffmpeg not found: fewer video/audio formats" : "ffmpeg: all video/audio formats"))
        menu.addItem(info(binaries.encoders.cwebp || binaries.encoders.ffmpeg ? "WebP: on" : "WebP: brew install webp"))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Log", action: #selector(openLog), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit rishabhfc", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
    }

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func openLog() { NSWorkspace.shared.open(Self.log) }
    @objc private func quit() { NSApp.terminate(nil) }
}

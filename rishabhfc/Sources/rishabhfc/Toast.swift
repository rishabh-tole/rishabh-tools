import AppKit

/// Small pill under the wheel: "PNG…" while working, then "✓ photo.png". Click it to show the result in Finder.
final class Toast {
    static let shared = Toast()

    /// Where the wheel opened; the toast sits just below it.
    var anchor: NSPoint?

    private let panel: NSPanel
    private let content = ToastView()
    private let label = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private let blur = NSVisualEffectView()
    private var pendingHide: DispatchWorkItem?

    private static let height: CGFloat = 36
    private static let maxWidth: CGFloat = 460

    private init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: Self.height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        blur.material = .hudWindow
        blur.state = .active
        blur.blendingMode = .behindWindow
        blur.wantsLayer = true
        blur.layer?.cornerRadius = Self.height / 2
        blur.layer?.masksToBounds = true
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle
        spinner.style = .spinning
        spinner.controlSize = .small
        [blur, spinner, label].forEach(content.addSubview)
        panel.contentView = content
    }

    func show(_ text: String, busy: Bool = false, reveal: [URL] = []) {
        pendingHide?.cancel()
        label.stringValue = text
        spinner.isHidden = !busy
        busy ? spinner.startAnimation(nil) : spinner.stopAnimation(nil)
        content.reveal = reveal
        layout(busy: busy)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        guard !busy else { return }
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (reveal.isEmpty ? 1.8 : 3.5), execute: work)
    }

    private func hide() {
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.2; panel.animator().alphaValue = 0 },
                                             completionHandler: { [weak self] in self?.panel.orderOut(nil) })
    }

    private func layout(busy: Bool) {
        let pad: CGFloat = 16, spin: CGFloat = busy ? 22 : 0
        let textWidth = min(label.fittingSize.width, Self.maxWidth - 2 * pad - spin)
        let width = textWidth + 2 * pad + spin
        let point = anchor ?? NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        var origin = NSPoint(x: point.x - width / 2, y: point.y - WheelView.radius - 56)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - Self.height - 8)
        }
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: Self.height)), display: true)
        blur.frame = content.bounds
        spinner.frame = NSRect(x: pad, y: (Self.height - 16) / 2, width: 16, height: 16)
        let labelHeight = label.fittingSize.height
        label.frame = NSRect(x: pad + spin, y: (Self.height - labelHeight) / 2, width: textWidth, height: labelHeight)
    }
}

private final class ToastView: NSView {
    var reveal: [URL] = []

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard !reveal.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(reveal)
    }
}

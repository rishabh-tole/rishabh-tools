import AppKit
import RishabhFCCore

/// Shows the wheel centered on the cursor in a floating, non-activating panel that sits above everything.
final class WheelController {
    var onDrop: ((Mode, Choice, [URL]) -> Void)?
    private(set) var mode: Mode?

    private let view = WheelView(frame: NSRect(x: 0, y: 0, width: WheelView.side, height: WheelView.side))
    private let panel: NSPanel
    private var pendingClose: DispatchWorkItem?

    init() {
        panel = NSPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.contentView = view
        view.onDrop = { [weak self] choice, files in
            guard let self, let mode = self.mode else { return }
            self.close()
            self.onDrop?(mode, choice, files)
        }
    }

    /// Opens at `point`, or swaps the choices in place when a wheel is already open.
    func open(_ mode: Mode, choices: [Choice], at point: NSPoint) {
        pendingClose?.cancel()
        if self.mode == nil {
            let half = WheelView.side / 2
            panel.setFrameOrigin(NSPoint(x: point.x - half, y: point.y - half))
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
            Toast.shared.anchor = point
        }
        self.mode = mode
        view.choices = choices
    }

    func close() {
        pendingClose?.cancel()
        guard mode != nil else { return }
        mode = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.mode == nil else { return }
            self.panel.orderOut(nil)
        })
    }

    /// The drag ended. A drop on the wheel arrives just after the mouse-up, so give it a moment.
    func closeSoon() {
        let work = DispatchWorkItem { [weak self] in self?.close() }
        pendingClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}

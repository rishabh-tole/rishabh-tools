import AppKit
import RishabhFCCore

/// Notices file drags in any app and reports modifier taps while one is in flight.
///
/// Needs no permissions: a global mouse-down monitor (mouse events don't need Accessibility) starts
/// a short-lived 60 Hz poll of the drag pasteboard and modifier keys, which stops when the button is released.
final class DragWatcher {
    var onTap: ((Mode, [URL]) -> Void)?
    var onEnd: (() -> Void)?

    private static let keys: [(NSEvent.ModifierFlags, Mode)] = [(.shift, .convert), (.command, .tools), (.control, .actions)]
    private static let watched: NSEvent.ModifierFlags = [.shift, .command, .control]

    private let pasteboard = NSPasteboard(name: .drag)
    private var monitor: Any?
    private var timer: Timer?
    private var seenCount = 0
    private var files: [URL] = []
    private var held: NSEvent.ModifierFlags = []

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in self?.mouseDown() }
    }

    private func mouseDown() {
        seenCount = pasteboard.changeCount
        files = []
        held = NSEvent.modifierFlags.intersection(Self.watched)
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else { return finish() }
        if files.isEmpty, pasteboard.changeCount != seenCount {
            seenCount = pasteboard.changeCount
            files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            Log.debug("drag pasteboard changed: \(files.count) file(s)")
        }
        // Keys already held when the drag started (Shift-click selections) only count once re-pressed.
        let now = NSEvent.modifierFlags.intersection(Self.watched)
        let pressed = now.subtracting(held)
        held = now
        if !pressed.isEmpty { Log.debug("pressed \(pressed.rawValue), files: \(files.count)") }
        guard !files.isEmpty, let mode = Self.keys.first(where: { pressed.contains($0.0) })?.1 else { return }
        onTap?(mode, files)
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        let wasDragging = !files.isEmpty
        files = []
        if wasDragging { onEnd?() }
    }
}

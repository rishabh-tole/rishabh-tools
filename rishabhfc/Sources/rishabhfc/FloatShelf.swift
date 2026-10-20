import AppKit

/// A small always-on-top shelf holding dragged files. Drag them back out into any app; close it when done.
final class FloatShelf: NSPanel, NSWindowDelegate {
    private static var open: [FloatShelf] = []

    static func show(_ files: [URL]) {
        let shelf = FloatShelf(files)
        open.append(shelf)
        shelf.orderFrontRegardless()
    }

    private init(_ files: [URL]) {
        let mouse = NSEvent.mouseLocation
        super.init(contentRect: NSRect(x: mouse.x - 70, y: mouse.y - 70, width: 140, height: 130),
                   styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = files.count == 1 ? files[0].lastPathComponent : "\(files.count) files"
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = ShelfView(files)
        delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        Self.open.removeAll { $0 === self }
    }
}

private final class ShelfView: NSView, NSDraggingSource {
    private let files: [URL]
    private let icon: NSImage

    init(_ files: [URL]) {
        self.files = files
        icon = NSWorkspace.shared.icon(forFiles: files.map(\.path)) ?? NSImage()
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private var iconRect: NSRect { NSRect(x: bounds.midX - 32, y: bounds.midY - 32, width: 64, height: 64) }

    override func draw(_ dirtyRect: NSRect) {
        icon.draw(in: iconRect)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDragged(with event: NSEvent) {
        let items = files.map { url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(iconRect, contents: icon)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move, .link, .generic]
    }
}

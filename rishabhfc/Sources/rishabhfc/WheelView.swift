import AppKit
import RishabhFCCore

/// The radial menu: a white disk, a hub holding the first choice and rounded ring slices for the rest.
/// It is also the drop target: hovering a slice lights it tangerine, dropping on it picks that choice.
final class WheelView: NSView {
    static let radius: CGFloat = 136
    static let margin: CGFloat = 30
    static var side: CGFloat { 2 * (radius + margin) }

    private let rim: CGFloat = 8
    private let hub: CGFloat = 46
    private let gap: CGFloat = 6
    private let corner: CGFloat = 9

    var choices: [Choice] = [] { didSet { hovered = nil; needsDisplay = true } }
    var onDrop: ((Choice, [URL]) -> Void)?
    /// Slot under the dragged file: 0 is the hub, 1... the ring.
    var hovered: Int? { didSet { if hovered != oldValue { needsDisplay = true } } }

    private var segments: Int { max(choices.count - 1, 0) }
    private var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
    private var geometry: WheelGeometry {
        WheelGeometry(segments: segments, radius: Double(Self.radius), hub: Double(hub + gap / 2), slack: 40)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: Drop target

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { track(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { track(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { hovered = nil }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let files = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        guard let slot = slot(for: sender), choices.indices.contains(slot), !files.isEmpty else { return false }
        onDrop?(choices[slot], files)
        return true
    }

    private func track(_ info: NSDraggingInfo) -> NSDragOperation {
        hovered = slot(for: info)
        return hovered == nil ? [] : .copy
    }

    private func slot(for info: NSDraggingInfo) -> Int? {
        let point = convert(info.draggingLocation, from: nil)
        return geometry.slot(atX: Double(point.x - center.x), y: Double(point.y - center.y))
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let palette = Palette(dark: effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        drawDisk(palette)
        for index in 0..<segments { drawSegment(index, palette) }
        drawHub(palette)
    }

    private func drawDisk(_ palette: Palette) {
        let disk = NSBezierPath(ovalIn: circle(Self.radius))
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 22
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.shadowColor = NSColor.black.withAlphaComponent(palette.dark ? 0.5 : 0.18)
        shadow.set()
        palette.disk.setFill()
        disk.fill()
        NSGraphicsContext.restoreGraphicsState()
        palette.edge.setStroke()
        disk.lineWidth = 1
        disk.stroke()
    }

    private func drawSegment(_ index: Int, _ palette: Palette) {
        let lit = hovered == index + 1
        let path = segmentPath(index)
        (lit ? Palette.tangerine : palette.segment).set()
        path.fill()
        if segments > 1 { path.stroke() }
        let mid = CGFloat(geometry.midAngle(ofSegment: index))
        let labelRadius = (Self.radius - rim + hub + gap) / 2
        let at = CGPoint(x: center.x + cos(mid) * labelRadius, y: center.y + sin(mid) * labelRadius)
        let width = segments > 1 ? min(Self.radius - rim - hub - gap, 2 * labelRadius * sin(.pi / CGFloat(segments))) : 120
        drawLabel(choices[index + 1].label, at: at, size: 11.5, maxWidth: width - 10, color: lit ? .white : palette.text)
    }

    /// Ring slice with rounded corners: fill and stroke a path inset by the corner radius with round joins.
    private func segmentPath(_ index: Int) -> NSBezierPath {
        let outerEdge = Self.radius - rim
        let innerEdge = hub + gap
        guard segments > 1 else {
            let ring = NSBezierPath(ovalIn: circle(outerEdge))
            ring.append(NSBezierPath(ovalIn: circle(innerEdge)))
            ring.windingRule = .evenOdd
            return ring
        }
        let outer = outerEdge - corner, inner = innerEdge + corner
        let mid = CGFloat(geometry.midAngle(ofSegment: index))
        let half = .pi / CGFloat(segments)
        let inset = gap / 2 + corner
        let outerHalf = half - inset / outer, innerHalf = half - inset / inner
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: outer, startAngle: degrees(mid + outerHalf),
                       endAngle: degrees(mid - outerHalf), clockwise: true)
        path.appendArc(withCenter: center, radius: inner, startAngle: degrees(mid - innerHalf),
                       endAngle: degrees(mid + innerHalf), clockwise: false)
        path.close()
        path.lineJoinStyle = .round
        path.lineWidth = corner * 2
        return path
    }

    private func drawHub(_ palette: Palette) {
        guard let first = choices.first else { return }
        let lit = hovered == 0
        let path = NSBezierPath(ovalIn: circle(hub))
        (lit ? Palette.tangerine : palette.hub).setFill()
        path.fill()
        if !lit {
            palette.edge.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        drawLabel(first.label, at: center, size: 10.5, maxWidth: hub * 2 - 14, color: lit ? .white : palette.text)
    }

    private func drawLabel(_ text: String, at point: CGPoint, size: CGFloat, maxWidth: CGFloat, color: NSColor) {
        let measure: (CGFloat) -> NSAttributedString = { size in
            NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: .bold),
                .foregroundColor: color,
                .kern: 0.4,
            ])
        }
        let natural = measure(size)
        let fitted = natural.size().width > maxWidth ? measure(max(8, size * maxWidth / natural.size().width)) : natural
        let box = fitted.size()
        fitted.draw(at: CGPoint(x: point.x - box.width / 2, y: point.y - box.height / 2))
    }

    private func circle(_ radius: CGFloat) -> NSRect {
        NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private func degrees(_ radians: CGFloat) -> CGFloat { radians * 180 / .pi }
}

private struct Palette {
    static let tangerine = NSColor(srgbRed: 0.95, green: 0.43, blue: 0.16, alpha: 1)

    let dark: Bool
    var disk: NSColor { dark ? NSColor(white: 0.15, alpha: 0.97) : NSColor(white: 0.995, alpha: 0.98) }
    var edge: NSColor { dark ? NSColor(white: 1, alpha: 0.10) : NSColor(white: 0, alpha: 0.08) }
    var segment: NSColor { dark ? NSColor(white: 0.25, alpha: 1) : NSColor(white: 0.925, alpha: 1) }
    var hub: NSColor { dark ? NSColor(white: 0.19, alpha: 1) : NSColor(white: 1, alpha: 1) }
    var text: NSColor { dark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.25, alpha: 1) }
}

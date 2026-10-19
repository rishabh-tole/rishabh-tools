import AppKit
import RishabhWMCore

struct ScreenInfo {
    let id: String
    /// Whole display, global top-left coordinates.
    let frame: Rect
    /// Display minus menu bar and Dock.
    let visible: Rect
    /// Holds the menu bar (System Settings → Displays → Main display).
    let isMain: Bool
    let isBuiltin: Bool
}

enum Screens {
    /// Displays left to right, converted from AppKit's bottom-left coordinates to AX top-left ones.
    static func current() -> [ScreenInfo] {
        guard let primary = NSScreen.screens.first else { return [] }
        let primaryHeight = primary.frame.height
        func convert(_ rect: NSRect) -> Rect {
            Rect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
        }
        return NSScreen.screens
            .map { screen in
                let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                return ScreenInfo(
                    id: number?.stringValue ?? screen.localizedName,
                    frame: convert(screen.frame),
                    visible: convert(screen.visibleFrame),
                    isMain: screen == primary,
                    isBuiltin: number.map { CGDisplayIsBuiltin($0.uint32Value) != 0 } ?? false
                )
            }
            .sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
    }

    static func worldScreens(_ infos: [ScreenInfo]) -> [Screen] {
        infos.map { Screen(id: $0.id, frame: $0.visible, isMain: $0.isMain, isBuiltin: $0.isBuiltin) }
    }

    /// Where to park a hidden window: just off an edge of the display it is on, leaving 1pt visible,
    /// at the first spot where the window doesn't spill onto another display. Displays of different
    /// sizes are often offset vertically, so bottom corners alone aren't always free.
    static func parkingOrigin(for frame: Rect, size: Rect, in screens: [ScreenInfo]) -> (x: Double, y: Double) {
        let screen = screens.first { $0.frame.contains(x: frame.midX, y: frame.midY) }
            ?? screens.min { $0.frame.distanceBetweenCenters(frame) < $1.frame.distanceBetweenCenters(frame) }
        guard let screen else { return (frame.x, frame.y) }
        let right = screen.frame.maxX - 1
        let left = screen.frame.minX - size.width + 1
        let bottom = screen.frame.maxY - 1
        let top = screen.visible.minY
        let candidates = [(right, bottom), (left, bottom), (right, top), (left, top)]
        let others = screens.filter { $0.id != screen.id }
        let free = candidates.first { x, y in
            let parked = Rect(x: x, y: y, width: size.width, height: size.height)
            return !others.contains { $0.frame.intersects(parked) }
        }
        return free ?? candidates[0]
    }
}

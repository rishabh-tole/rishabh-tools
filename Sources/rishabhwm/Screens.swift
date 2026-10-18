import AppKit
import RishabhWMCore

struct ScreenInfo {
    let id: String
    /// Whole display, global top-left coordinates.
    let frame: Rect
    /// Display minus menu bar and Dock.
    let visible: Rect
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
                    visible: convert(screen.visibleFrame)
                )
            }
            .sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
    }

    static func worldScreens(_ infos: [ScreenInfo]) -> [Screen] {
        infos.map { Screen(id: $0.id, frame: $0.visible) }
    }

    /// Where to park a hidden window: a corner of the display it is on, leaving 1pt visible,
    /// on the side that has no neighboring display (so it can't spill onto another screen).
    static func parkingOrigin(for frame: Rect, size: Rect, in screens: [ScreenInfo]) -> (x: Double, y: Double) {
        let screen = screens.first { $0.frame.contains(x: frame.midX, y: frame.midY) }
            ?? screens.min { $0.frame.distanceBetweenCenters(frame) < $1.frame.distanceBetweenCenters(frame) }
        guard let screen else { return (frame.x, frame.y) }
        let y = screen.frame.maxY - 1
        let rightFree = !screens.contains { $0.frame.contains(x: screen.frame.maxX + 1, y: y) }
        let x = rightFree ? screen.frame.maxX - 1 : screen.frame.minX - size.width + 1
        return (x, y)
    }
}

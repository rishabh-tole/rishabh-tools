import AppKit
import ApplicationServices
import RishabhWMCore

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Thin wrappers over the Accessibility API.
enum AX {
    static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        (copy(element, attribute) as? Bool) ?? false
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func app(_ pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        return app
    }

    static func windows(ofApp app: AXUIElement) -> [AXUIElement] {
        (copy(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    }

    static func focusedWindow(ofApp app: AXUIElement) -> AXUIElement? {
        element(app, kAXFocusedWindowAttribute)
    }

    static func windowID(_ element: AXUIElement) -> WindowID? {
        var id: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    static func isFullscreen(_ window: AXUIElement) -> Bool { bool(window, "AXFullScreen") }

    /// Normal app windows only: no dialogs, sheets, panels, minimized or native-fullscreen windows.
    static func isManageable(_ window: AXUIElement) -> Bool {
        string(window, kAXRoleAttribute) == kAXWindowRole
            && string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole
            && !bool(window, kAXMinimizedAttribute)
            && !isFullscreen(window)
    }

    static func frame(_ window: AXUIElement) -> Rect? {
        guard let positionRef = copy(window, kAXPositionAttribute),
              let sizeRef = copy(window, kAXSizeAttribute),
              CFGetTypeID(positionRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return Rect(x: point.x, y: point.y, width: size.width, height: size.height)
    }

    static func setPosition(_ window: AXUIElement, x: Double, y: Double) {
        var point = CGPoint(x: x, y: y)
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    static func setSize(_ window: AXUIElement, width: Double, height: Double) {
        var size = CGSize(width: width, height: height)
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    /// Size, position, size: the second size fixes windows clamped while still on the old position.
    /// Enhanced UI (turned on by VoiceOver-style tools) animates every resize, so it is paused meanwhile.
    static func setFrame(_ window: AXUIElement, app: AXUIElement, _ rect: Rect) {
        let enhanced = bool(app, "AXEnhancedUserInterface")
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }
        setSize(window, width: rect.width, height: rect.height)
        setPosition(window, x: rect.x, y: rect.y)
        setSize(window, width: rect.width, height: rect.height)
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) }
    }

    static func raise(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    static func close(_ window: AXUIElement) {
        guard let button = element(window, kAXCloseButtonAttribute) else { return }
        AXUIElementPerformAction(button, kAXPressAction as CFString)
    }
}

/// Hashable wrapper so AX elements can be compared (CFEqual) and used as keys.
struct ElementKey: Hashable {
    let element: AXUIElement

    static func == (lhs: ElementKey, rhs: ElementKey) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

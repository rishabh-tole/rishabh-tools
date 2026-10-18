import AppKit
import ApplicationServices
import RishabhWMCore

enum WindowEvent {
    case created(AXUIElement)
    case focusChanged
    case destroyed(WindowID)
    case geometryChanged(WindowID)
    case minimized(WindowID)
}

/// One AXObserver per running app: window created / focused at the app level, plus
/// destroyed / moved / resized / minimized per watched window.
final class AppObserver {
    let pid: pid_t
    let app: AXUIElement
    let bundleID: String?

    private var observer: AXObserver?
    private var watched: [ElementKey: WindowID] = [:]
    private let onEvent: (pid_t, WindowEvent) -> Void

    private static let appNotifications = [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification]
    private static let windowNotifications = [
        kAXUIElementDestroyedNotification, kAXWindowMovedNotification,
        kAXWindowResizedNotification, kAXWindowMiniaturizedNotification,
    ]

    init?(app running: NSRunningApplication, onEvent: @escaping (pid_t, WindowEvent) -> Void) {
        pid = running.processIdentifier
        app = AX.app(pid)
        bundleID = running.bundleIdentifier
        self.onEvent = onEvent

        var created: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            Unmanaged<AppObserver>.fromOpaque(refcon).takeUnretainedValue().handle(element, notification as String)
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return nil }
        observer = created
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        subscribeApp(attempt: 0)
    }

    deinit {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
    }

    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

    /// Freshly launched apps often reject observers for a moment; retry a few times.
    private func subscribeApp(attempt: Int) {
        guard let observer else { return }
        let results = Self.appNotifications.map { AXObserverAddNotification(observer, app, $0 as CFString, refcon) }
        let ok = results.allSatisfy { $0 == .success || $0 == .notificationAlreadyRegistered }
        guard !ok, attempt < 5 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 * Double(attempt + 1)) { [weak self] in
            self?.subscribeApp(attempt: attempt + 1)
        }
    }

    func watch(_ window: AXUIElement, id: WindowID) {
        guard let observer, watched[ElementKey(element: window)] == nil else { return }
        watched[ElementKey(element: window)] = id
        Self.windowNotifications.forEach { AXObserverAddNotification(observer, window, $0 as CFString, refcon) }
    }

    func unwatch(_ id: WindowID) {
        guard let key = watched.first(where: { $0.value == id })?.key else { return }
        watched[key] = nil
        if let observer {
            Self.windowNotifications.forEach { AXObserverRemoveNotification(observer, key.element, $0 as CFString) }
        }
    }

    private func handle(_ element: AXUIElement, _ notification: String) {
        let id = watched[ElementKey(element: element)]
        switch notification {
        case kAXWindowCreatedNotification:
            onEvent(pid, .created(element))
        case kAXFocusedWindowChangedNotification:
            onEvent(pid, .focusChanged)
        case kAXUIElementDestroyedNotification:
            guard let id else { return }
            watched[ElementKey(element: element)] = nil
            onEvent(pid, .destroyed(id))
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            if let id { onEvent(pid, .geometryChanged(id)) }
        case kAXWindowMiniaturizedNotification:
            if let id { onEvent(pid, .minimized(id)) }
        default:
            break
        }
    }
}

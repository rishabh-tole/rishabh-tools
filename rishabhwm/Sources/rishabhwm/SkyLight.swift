import AppKit
import RishabhWMCore

/// Read-only bits of the private SkyLight (WindowServer) API, loaded lazily with dlsym.
/// Works with SIP fully enabled. Every call degrades to nil if Apple removes a symbol.
enum SkyLight {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias ActiveSpace = @convention(c) (Int32) -> UInt64
    private typealias SpaceType = @convention(c) (Int32, UInt64) -> Int32
    private typealias DisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias WindowSpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias FrontProcess = @convention(c) (UnsafeMutableRawPointer, UInt32, UInt32) -> Int32
    private typealias ProcessForPID = @convention(c) (pid_t, UnsafeMutableRawPointer) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, _ type: T.Type) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }

    private static let connection: Int32? = symbol("SLSMainConnectionID", MainConnection.self)?()
    private static let activeSpaceFn = symbol("SLSGetActiveSpace", ActiveSpace.self)
    private static let spaceTypeFn = symbol("SLSSpaceGetType", SpaceType.self)
    private static let displaySpacesFn = symbol("SLSCopyManagedDisplaySpaces", DisplaySpaces.self)
    private static let windowSpacesFn = symbol("SLSCopySpacesForWindows", WindowSpaces.self)
    private static let frontProcessFn = symbol("_SLPSSetFrontProcessWithOptions", FrontProcess.self)
    private static let processForPIDFn: ProcessForPID? = {
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "GetProcessForPID") else { return nil }
        return unsafeBitCast(pointer, to: ProcessForPID.self)
    }()

    static var isAvailable: Bool { connection != nil && activeSpaceFn != nil && displaySpacesFn != nil }

    static func activeSpace() -> UInt64? {
        guard let connection, let fn = activeSpaceFn else { return nil }
        return fn(connection)
    }

    /// 0 = normal desktop, 4 = native fullscreen.
    static func spaceType(_ space: UInt64) -> Int32? {
        guard let connection, let fn = spaceTypeFn else { return nil }
        return fn(connection, space)
    }

    /// The "home" Space of every display: its first normal desktop (Desktop 1).
    static func homeSpaces() -> Set<UInt64>? {
        guard let connection, let fn = displaySpacesFn,
              let displays = fn(connection)?.takeRetainedValue() as? [[String: Any]]
        else { return nil }
        let homes = displays.compactMap { display -> UInt64? in
            let spaces = display["Spaces"] as? [[String: Any]] ?? []
            let desktop = spaces.first { ($0["type"] as? NSNumber)?.intValue == 0 }
            return (desktop?["id64"] as? NSNumber)?.uint64Value
        }
        return Set(homes)
    }

    static func spaces(ofWindow id: WindowID) -> [UInt64]? {
        guard let connection, let fn = windowSpacesFn else { return nil }
        let ids = [NSNumber(value: id)] as CFArray
        guard let spaces = fn(connection, 0x7, ids)?.takeRetainedValue() as? [NSNumber] else { return nil }
        return spaces.map(\.uint64Value)
    }

    /// Brings a specific window's app to front and switches to that window's Space.
    @discardableResult
    static func focus(pid: pid_t, window: WindowID) -> Bool {
        guard let front = frontProcessFn, let processForPID = processForPIDFn else { return false }
        var psn = [UInt32](repeating: 0, count: 2)
        return psn.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress, processForPID(pid, base) == 0 else { return false }
            return front(base, window, 0x200) == 0 // kCPSUserGenerated
        }
    }
}

/// Answers "is this the home desktop?" so rishabhwm can stay out of fullscreen apps and other Spaces.
enum Spaces {
    static func isOnHome() -> Bool {
        guard let active = SkyLight.activeSpace(), let homes = SkyLight.homeSpaces(), !homes.isEmpty else {
            return !frontWindowIsFullscreen()
        }
        return homes.contains(active)
    }

    static func isOnHome(window id: WindowID) -> Bool {
        guard let spaces = SkyLight.spaces(ofWindow: id), let homes = SkyLight.homeSpaces(), !homes.isEmpty else {
            return true
        }
        return !homes.isDisjoint(with: spaces)
    }

    private static func frontWindowIsFullscreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let window = AX.focusedWindow(ofApp: AX.app(app.processIdentifier))
        else { return false }
        return AX.isFullscreen(window)
    }
}

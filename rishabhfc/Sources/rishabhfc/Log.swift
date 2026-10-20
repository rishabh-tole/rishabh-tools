import Foundation

/// stderr logging; the LaunchAgent sends it to ~/Library/Logs/rishabhfc.log.
enum Log {
    static var verbose = ProcessInfo.processInfo.environment["RISHABHFC_DEBUG"] != nil

    static func info(_ message: @autoclosure () -> String) { write("info", message()) }
    static func error(_ message: @autoclosure () -> String) { write("error", message()) }
    static func debug(_ message: @autoclosure () -> String) {
        if verbose { write("debug", message()) }
    }

    private static func write(_ level: String, _ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        FileHandle.standardError.write(Data("\(stamp) [\(level)] \(message)\n".utf8))
    }
}

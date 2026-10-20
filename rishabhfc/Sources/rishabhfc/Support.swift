import Foundation
import RishabhFCCore

enum JobError: LocalizedError {
    case unreadable(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let name): return "Can't read \(name)"
        case .failed(let message): return message
        }
    }
}

/// Optional Homebrew encoders. LaunchAgents get a bare PATH, so look in the usual places directly.
struct Binaries {
    let ffmpeg: String?
    let cwebp: String?

    var encoders: Encoders { Encoders(ffmpeg: ffmpeg != nil, cwebp: cwebp != nil) }

    /// `RISHABHFC_NATIVE=1` ignores them, to exercise the built-in fallbacks.
    static func find() -> Binaries {
        if ProcessInfo.processInfo.environment["RISHABHFC_NATIVE"] != nil { return Binaries(ffmpeg: nil, cwebp: nil) }
        let dirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        let look: (String) -> String? = { name in
            dirs.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
        }
        return Binaries(ffmpeg: look("ffmpeg"), cwebp: look("cwebp"))
    }
}

enum Shell {
    /// Runs a tool to completion; throws its last stderr line on failure. `stdout` redirects output to a file.
    static func run(_ tool: String, _ args: [String], in directory: URL? = nil, stdout: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        if let stdout {
            FileManager.default.createFile(atPath: stdout.path, contents: nil)
            process.standardOutput = try FileHandle(forWritingTo: stdout)
        } else {
            process.standardOutput = FileHandle.nullDevice
        }
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        let output = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let lines = String(decoding: output, as: UTF8.self).split(separator: "\n")
            let name = (tool as NSString).lastPathComponent
            throw JobError.failed(lines.last.map { "\(name): \($0)" } ?? "\(name) failed")
        }
    }
}

/// Where results go: beside the source, never overwriting.
enum Output {
    static func beside(_ source: URL, ext: String, suffix: String = "") -> URL {
        let base = OutputName.base(of: source.lastPathComponent) + suffix
        return OutputName.unique(in: source.deletingLastPathComponent(), base: base, ext: ext, exists: exists)
    }

    /// A free spot for `name` (keeping its extension) in `directory`.
    static func free(_ name: String, in directory: URL) -> URL {
        let base = OutputName.base(of: name)
        let ext = name.count > base.count ? String(name.dropFirst(base.count + 1)) : ""
        return OutputName.unique(in: directory, base: base, ext: ext, exists: exists)
    }

    static func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    /// Runs `body` to create `url`; a half-written result is removed if it throws.
    @discardableResult
    static func produce(_ url: URL, _ body: () throws -> Void) throws -> URL {
        do {
            try body()
            return url
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    /// Scratch folder for intermediate files, removed afterwards.
    static func withScratch<T>(_ body: (URL) throws -> T) throws -> T {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("rishabhfc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try body(dir)
    }
}

/// AppKit text and printing must run on the main thread; jobs run on a background queue.
func onMain<T>(_ body: () throws -> T) throws -> T {
    if Thread.isMainThread { return try body() }
    return try DispatchQueue.main.sync { try body() }
}

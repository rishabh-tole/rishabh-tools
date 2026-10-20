import Foundation
import RishabhFCCore

/// ZIP and TAR.GZ with the system's ditto, zip and tar.
enum ArchiveEngine {
    /// One item → `name.zip`; a selection → `Archive.zip` beside the first item.
    static func pack(_ files: [URL], ext: String) throws -> URL {
        let directory = commonParent(files)
        let single = files.count == 1
        let isFolder = Catalog.kind(of: Item(url: files[0])) == .folder
        let base = !single ? "Archive" : isFolder ? files[0].lastPathComponent : OutputName.base(of: files[0].lastPathComponent)
        let out = OutputName.unique(in: files[0].deletingLastPathComponent(), base: base, ext: ext, exists: Output.exists)
        // Paths relative to the shared parent; "./" keeps a file named like "-rf" from being read as a flag.
        let names = files.map { "./" + $0.standardizedFileURL.path.dropFirst(directory.path.count).drop { $0 == "/" } }
        return try Output.produce(out) {
            if ext == "tar.gz" { return try Shell.run("/usr/bin/tar", ["-czf", out.path, "-C", directory.path] + names) }
            if single { return try Shell.run("/usr/bin/ditto", ["-c", "-k", "--norsrc", "--noextattr", "--noacl", "--keepParent", files[0].path, out.path]) }
            try Shell.run("/usr/bin/zip", ["-r", "-q", "-y", out.path] + names + ["-x", "*.DS_Store"], in: directory)
        }
    }

    /// Unpacks into a folder named after the archive; a lone top-level item is lifted out, like Archive Utility.
    static func extract(_ url: URL) throws -> URL {
        let directory = url.deletingLastPathComponent()
        let folder = Output.beside(url, ext: "")
        try Output.produce(folder) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try unpack(url, into: folder)
        }
        let contents = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0 != "__MACOSX" && $0 != ".DS_Store" }
        guard contents.count == 1 else { return folder }
        // Park the item, drop the wrapper, then name it: the wrapper's own name may be the one it should get.
        let parked = directory.appendingPathComponent(".rishabhfc-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: folder.appendingPathComponent(contents[0]), to: parked)
        try FileManager.default.removeItem(at: folder)
        let lifted = Output.free(contents[0], in: directory)
        try FileManager.default.moveItem(at: parked, to: lifted)
        return lifted
    }

    /// ZIP ⇄ TAR.GZ through a scratch folder.
    static func repack(_ url: URL, to ext: String) throws -> URL {
        let out = Output.beside(url, ext: ext)
        return try Output.produce(out) {
            try Output.withScratch { scratch in
                try unpack(url, into: scratch)
                let items = try FileManager.default.contentsOfDirectory(atPath: scratch.path)
                    .filter { $0 != "__MACOSX" }.map { "./" + $0 }
                if ext == "tar.gz" { return try Shell.run("/usr/bin/tar", ["-czf", out.path, "-C", scratch.path] + items) }
                try Shell.run("/usr/bin/zip", ["-r", "-q", "-y", out.path] + items, in: scratch)
            }
        }
    }

    /// Deepest folder containing every item.
    private static func commonParent(_ files: [URL]) -> URL {
        let paths = files.map { $0.standardizedFileURL.deletingLastPathComponent().pathComponents }
        let shared = paths.dropFirst().reduce(paths[0]) { prefix, next in
            Array(zip(prefix, next).prefix { $0 == $1 }.map(\.0))
        }
        return URL(fileURLWithPath: NSString.path(withComponents: shared), isDirectory: true)
    }

    private static func unpack(_ url: URL, into folder: URL) throws {
        switch Catalog.normalizedExtension(of: url.lastPathComponent) {
        case "zip": try Shell.run("/usr/bin/ditto", ["-x", "-k", url.path, folder.path])
        case "gz":
            let target = folder.appendingPathComponent(OutputName.base(of: url.lastPathComponent))
            try Shell.run("/usr/bin/gzip", ["-dc", url.path], stdout: target)
        default: try Shell.run("/usr/bin/tar", ["-xf", url.path, "-C", folder.path])
        }
    }
}

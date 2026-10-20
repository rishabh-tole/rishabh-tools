import Foundation
import RishabhFCCore

/// Routes a wheel choice to the engine for each file's kind. Runs on a background queue.
enum Jobs {
    static func run(_ mode: Mode, _ choice: Choice, files: [URL], binaries: Binaries) throws -> [URL] {
        switch mode {
        case .convert: return try convert(choice.id, files, binaries)
        case .tools: return try tool(choice.id, files, binaries)
        case .actions: return []
        }
    }

    private static func convert(_ id: String, _ files: [URL], _ binaries: Binaries) throws -> [URL] {
        let kinds = files.map { Catalog.kind(of: Item(url: $0)) }
        let archiveAll = ["zip", "tar.gz"].contains(id) && (files.count > 1 || kinds[0] == .folder || kinds[0] == .other)
        if archiveAll { return [try ArchiveEngine.pack(files, ext: id)] }
        return try zip(files, kinds).map { url, kind in
            switch kind {
            case .image: return try ImageEngine.convert(url, to: id, binaries: binaries)
            case .video, .audio: return try MediaEngine.convert(url, to: id, kind: kind, binaries: binaries)
            case .pdf: return try PDFEngine.convert(url, to: id)
            case .document: return try DocEngine.convert(url, to: id)
            case .table, .subtitle: return try TextEngine.convert(url, to: id)
            case .archive: return id == "extract" ? try ArchiveEngine.extract(url) : try ArchiveEngine.repack(url, to: id)
            case .folder, .other: return try ArchiveEngine.pack([url], ext: id)
            }
        }
    }

    private static func tool(_ id: String, _ files: [URL], _ binaries: Binaries) throws -> [URL] {
        switch id {
        case "combine": return [try ImageEngine.combine(files)]
        case "merge": return [try PDFEngine.merge(files)]
        default: break
        }
        return try files.map { url in
            switch Catalog.kind(of: Item(url: url)) {
            case .image: return try ImageEngine.tool(id, url, binaries: binaries)
            case .pdf: return try PDFEngine.tool(id, url)
            case .video: return try MediaEngine.tool(id, url, binaries: binaries)
            default: throw JobError.failed("No \(id) for \(url.lastPathComponent)")
            }
        }
    }
}

import Foundation

/// What a dragged item is, decided by its file extension.
public enum Kind: String, Sendable {
    case image, video, audio, pdf, document, table, subtitle, archive, folder, other
}

/// Which wheel is showing: Shift converts, Command opens tools, Control opens file actions.
public enum Mode: String, Sendable {
    case convert, tools, actions
}

/// Optional command-line encoders found on this Mac. They widen the format list; nothing requires them.
public struct Encoders: Equatable, Sendable {
    public let ffmpeg: Bool
    public let cwebp: Bool

    public init(ffmpeg: Bool = false, cwebp: Bool = false) {
        self.ffmpeg = ffmpeg
        self.cwebp = cwebp
    }
}

/// A dragged file or folder, described by name only so the catalog stays pure.
public struct Item: Equatable, Sendable {
    public let name: String
    public let isDirectory: Bool

    public init(name: String, isDirectory: Bool) {
        self.name = name
        self.isDirectory = isDirectory
    }
}

/// One slot on the wheel. `id` is the output extension for conversions, or a verb for tools and actions.
public struct Choice: Equatable, Hashable, Sendable {
    public let id: String
    public let label: String

    public init(_ id: String, _ label: String) {
        self.id = id
        self.label = label
    }
}

public enum Catalog {
    static let aliases = [
        "jpeg": "jpg", "tif": "tiff", "heif": "heic", "aif": "aiff", "htm": "html",
        "markdown": "md", "tgz": "tar.gz", "mpeg": "mpg",
    ]

    static let kinds: [Kind: Set<String>] = [
        .image: ["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "gif", "svg", "ico", "icns", "psd", "tga"],
        .video: ["mp4", "mov", "m4v", "mkv", "webm", "avi", "wmv", "flv", "mpg", "3gp"],
        .audio: ["mp3", "m4a", "wav", "aiff", "flac", "ogg", "opus", "wma", "aac", "caf"],
        .pdf: ["pdf"],
        .document: ["txt", "md", "rtf", "rtfd", "html", "doc", "docx", "odt"],
        .table: ["csv", "tsv"],
        .subtitle: ["srt", "vtt"],
        .archive: ["zip", "tar", "tar.gz", "gz"],
    ]

    /// Sources AVFoundation / afconvert can read without ffmpeg.
    static let nativeVideo: Set<String> = ["mp4", "mov", "m4v", "3gp"]
    static let nativeAudio: Set<String> = ["mp3", "m4a", "wav", "aiff", "flac", "aac", "caf"]

    static let labels = [
        "tar.gz": "TAR.GZ", "extract": "EXTRACT", "copypath": "COPY PATH",
    ]

    /// Lower-cased, alias-folded extension; `.tar.gz` counts as one extension.
    public static func normalizedExtension(of name: String) -> String {
        let lower = name.lowercased()
        if lower.hasSuffix(".tar.gz") { return "tar.gz" }
        let ext = (lower as NSString).pathExtension
        return aliases[ext] ?? ext
    }

    public static func kind(of item: Item) -> Kind {
        if item.isDirectory { return .folder }
        let ext = normalizedExtension(of: item.name)
        return kinds.first { $0.value.contains(ext) }?.key ?? .other
    }

    /// Wheel slots for the selection, center first. A selection gets what every item shares.
    public static func choices(_ mode: Mode, for items: [Item], encoders: Encoders) -> [Choice] {
        guard !items.isEmpty else { return [] }
        let perItem = items.map { ids(mode, for: $0, selection: items, encoders: encoders) }
        let common = perItem[0].filter { id in perItem.allSatisfy { $0.contains(id) } }
        let archiveAll = mode == .convert && items.count > 1 && !common.contains("zip")
        let shared = archiveAll ? common + ["zip"] : common
        return shared.map { Choice($0, labels[$0] ?? $0.uppercased()) }
    }

    private static func ids(_ mode: Mode, for item: Item, selection: [Item], encoders: Encoders) -> [String] {
        switch mode {
        case .convert: return conversions(for: item, encoders: encoders)
        case .tools: return tools(for: kind(of: item), selection: selection)
        case .actions: return ["airdrop", "float", "copy", "move", "copypath", "terminal"]
        }
    }

    private static func conversions(for item: Item, encoders: Encoders) -> [String] {
        let ext = normalizedExtension(of: item.name)
        let others: ([String]) -> [String] = { $0.filter { $0 != ext } }
        switch kind(of: item) {
        case .image:
            let webp = encoders.cwebp || encoders.ffmpeg
            return others(["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "pdf"]).filter { $0 != "webp" || webp }
        case .video:
            if encoders.ffmpeg { return others(["mp4", "mov", "mkv", "webm", "avi", "gif", "mp3", "m4a"]) }
            return nativeVideo.contains(ext) ? others(["mp4", "mov", "gif", "m4a"]) : []
        case .audio:
            if encoders.ffmpeg { return others(["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"]) }
            return nativeAudio.contains(ext) ? others(["m4a", "wav", "flac", "aiff"]) : []
        case .pdf: return ["docx", "jpg", "png", "txt", "rtf", "html"]
        case .document: return others(["pdf", "docx", "rtf", "txt", "html", "odt"])
        case .table: return others(["csv", "tsv"])
        case .subtitle: return others(["srt", "vtt"]) + ["txt"]
        case .archive: return ["extract"] + (ext == "zip" ? ["tar.gz"] : ["zip"])
        case .folder: return ["zip", "tar.gz"]
        case .other: return ["zip"]
        }
    }

    private static func tools(for kind: Kind, selection: [Item]) -> [String] {
        let many = selection.count > 1
        switch kind {
        case .image: return ["compress", "metadata", "resize", "rotate"] + (many ? ["combine"] : [])
        case .pdf: return ["compress", "split"] + (many ? ["merge"] : [])
        case .video: return ["compress", "mute"]
        default: return []
        }
    }
}

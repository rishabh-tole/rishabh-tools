import AVFoundation
import ImageIO
import RishabhFCCore
import UniformTypeIdentifiers

/// Video and audio. ffmpeg when it's installed (more formats), otherwise AVFoundation and afconvert.
enum MediaEngine {
    private static let quiet = ["-hide_banner", "-loglevel", "error", "-nostdin", "-n"]
    private static let h264 = ["-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p"]

    private static let ffmpegArgs: [String: [String]] = [
        "mp4": h264 + ["-crf", "23", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"],
        "mov": h264 + ["-crf", "23", "-c:a", "aac", "-b:a", "192k"],
        "mkv": h264 + ["-crf", "23", "-c:a", "aac", "-b:a", "192k"],
        "webm": ["-c:v", "libvpx-vp9", "-crf", "33", "-b:v", "0", "-row-mt", "1", "-deadline", "good",
                 "-cpu-used", "4", "-c:a", "libopus", "-b:a", "128k"],
        "avi": ["-c:v", "mpeg4", "-q:v", "4", "-c:a", "libmp3lame", "-q:a", "4"],
        "gif": ["-vf", "fps=12,scale='min(640,iw)':-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse",
                "-loop", "0"],
        "mp3": ["-vn", "-c:a", "libmp3lame", "-q:a", "2"],
        "m4a": ["-vn", "-c:a", "aac", "-b:a", "256k"],
        "wav": ["-vn", "-c:a", "pcm_s16le"],
        "flac": ["-vn", "-c:a", "flac"],
        "ogg": ["-vn", "-c:a", "vorbis", "-strict", "-2", "-ac", "2", "-q:a", "5"],
        "opus": ["-vn", "-c:a", "libopus", "-b:a", "128k"],
        "aiff": ["-vn", "-c:a", "pcm_s16be"],
        "wma": ["-vn", "-c:a", "wmav2", "-b:a", "192k"],
    ]

    private static let afconvertArgs: [String: [String]] = [
        "m4a": ["-f", "m4af", "-d", "aac", "-b", "256000"],
        "wav": ["-f", "WAVE", "-d", "LEI16"],
        "flac": ["-f", "flac", "-d", "flac"],
        "aiff": ["-f", "AIFF", "-d", "BEI16"],
    ]

    static func convert(_ url: URL, to ext: String, kind: Kind, binaries: Binaries) throws -> URL {
        let out = Output.beside(url, ext: ext)
        return try Output.produce(out) {
            if let ffmpeg = binaries.ffmpeg, let args = ffmpegArgs[ext] {
                return try Shell.run(ffmpeg, quiet + ["-i", url.path] + args + [out.path])
            }
            if kind == .audio, let args = afconvertArgs[ext] {
                return try Shell.run("/usr/bin/afconvert", args + [url.path, out.path])
            }
            let asset = AVURLAsset(url: url)
            switch ext {
            case "gif": try gif(asset, to: out)
            case "m4a": try export(asset, preset: AVAssetExportPresetAppleM4A, type: .m4a, to: out)
            case "mov": try export(asset, preset: AVAssetExportPresetHighestQuality, type: .mov, to: out)
            case "mp4": try export(asset, preset: AVAssetExportPresetHighestQuality, type: .mp4, to: out)
            default: throw JobError.failed("\(ext.uppercased()) needs ffmpeg (brew install ffmpeg)")
            }
        }
    }

    static func tool(_ id: String, _ url: URL, binaries: Binaries) throws -> URL {
        let source = Catalog.normalizedExtension(of: url.lastPathComponent)
        switch id {
        case "compress":
            let ext = ["mp4", "mov", "mkv"].contains(source) ? source : "mp4"
            let out = Output.beside(url, ext: ext, suffix: " compressed")
            return try Output.produce(out) {
                if let ffmpeg = binaries.ffmpeg {
                    let args = ["-vf", "scale='min(1920,iw)':-2"] + h264 + ["-crf", "28", "-c:a", "aac", "-b:a", "128k"]
                    return try Shell.run(ffmpeg, quiet + ["-i", url.path] + args + [out.path])
                }
                try export(AVURLAsset(url: url), preset: AVAssetExportPresetHEVC1920x1080, type: fileType(ext), to: out)
            }
        case "mute":
            let out = Output.beside(url, ext: source, suffix: " muted")
            return try Output.produce(out) {
                if let ffmpeg = binaries.ffmpeg {
                    return try Shell.run(ffmpeg, quiet + ["-i", url.path, "-c", "copy", "-an", out.path])
                }
                try export(try videoOnly(AVURLAsset(url: url)), preset: AVAssetExportPresetPassthrough, type: fileType(source), to: out)
            }
        default:
            throw JobError.failed("Unknown tool \(id)")
        }
    }

    private static func fileType(_ ext: String) -> AVFileType { ext == "mov" ? .mov : ext == "m4v" ? .m4v : .mp4 }

    private static func export(_ asset: AVAsset, preset: String, type: AVFileType, to out: URL) throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw JobError.failed("Can't export this file")
        }
        session.outputURL = out
        session.outputFileType = type
        session.shouldOptimizeForNetworkUse = true
        let done = DispatchSemaphore(value: 0)
        session.exportAsynchronously { done.signal() }
        done.wait()
        guard session.status == .completed else {
            throw JobError.failed(session.error?.localizedDescription ?? "Export failed")
        }
    }

    private static func videoOnly(_ asset: AVAsset) throws -> AVAsset {
        let composition = AVMutableComposition()
        let range = CMTimeRange(start: .zero, duration: try wait { try await asset.load(.duration) })
        for track in try wait({ try await asset.loadTracks(withMediaType: .video) }) {
            let copy = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            try copy?.insertTimeRange(range, of: track, at: .zero)
            copy?.preferredTransform = try wait { try await track.load(.preferredTransform) }
        }
        return composition
    }

    /// 10 fps, at most 640 px wide and 60 seconds long.
    private static func gif(_ asset: AVAsset, to out: URL) throws {
        let fps = 10.0
        let seconds = min(CMTimeGetSeconds(try wait { try await asset.load(.duration) }), 60)
        let frames = max(1, Int(seconds * fps))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, frames, nil) else {
            throw JobError.failed("Can't write GIF")
        }
        let loop = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, loop as CFDictionary)
        let delay = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
        for index in 0..<frames {
            let time = CMTime(seconds: Double(index) / fps, preferredTimescale: 600)
            guard let frame = try? generator.copyCGImage(at: time, actualTime: nil) else { continue }
            CGImageDestinationAddImage(destination, frame, delay)
        }
        guard CGImageDestinationFinalize(destination) else { throw JobError.failed("Couldn't save GIF") }
    }

    /// Bridges AVFoundation's async property loading into these synchronous background jobs.
    private static func wait<T>(_ work: @escaping () async throws -> T) throws -> T {
        let box = ResultBox<T>()
        let done = DispatchSemaphore(value: 0)
        Task {
            do { box.result = .success(try await work()) } catch { box.result = .failure(error) }
            done.signal()
        }
        done.wait()
        return try box.result!.get()
    }
}

/// Hands a value back from a Task to the thread blocked waiting on it.
private final class ResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}

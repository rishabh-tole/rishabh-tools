import AppKit
import ImageIO
import RishabhFCCore
import UniformTypeIdentifiers

/// Images through ImageIO. WebP goes through cwebp (or ffmpeg) since ImageIO can read it but not write it.
enum ImageEngine {
    private static let types: [String: UTType] = [
        "jpg": .jpeg, "png": .png, "heic": .heic, "tiff": .tiff, "bmp": .bmp, "gif": .gif,
        "avif": UTType("public.avif") ?? .heic,
    ]
    private static let maxCompressed = 2048

    struct Picture {
        let image: CGImage
        /// Source metadata with orientation reset (the pixels are already upright).
        let properties: [CFString: Any]
    }

    static func convert(_ url: URL, to ext: String, binaries: Binaries) throws -> URL {
        let picture = try load(url)
        let out = Output.beside(url, ext: ext)
        return try Output.produce(out) {
            if ext == "pdf" { return try writePDF([picture.image], to: out) }
            try write(picture.image, ext: ext, to: out, quality: 0.9, properties: picture.properties, binaries: binaries)
        }
    }

    static func tool(_ id: String, _ url: URL, binaries: Binaries) throws -> URL {
        let source = Catalog.normalizedExtension(of: url.lastPathComponent)
        let ext = (types[source] != nil || source == "webp") && source != "gif" ? source : "png"
        switch id {
        case "compress":
            let picture = try load(url, maxPixels: maxCompressed)
            return try save(picture.image, like: url, ext: ext, suffix: " compressed", quality: 0.6, properties: picture.properties, binaries)
        case "metadata":
            let picture = try load(url)
            return try save(picture.image, like: url, ext: ext, suffix: " clean", quality: 0.95, properties: [:], binaries)
        case "resize":
            let full = try load(url)
            let half = try load(url, maxPixels: max(full.image.width, full.image.height) / 2)
            return try save(half.image, like: url, ext: ext, suffix: " half", quality: 0.9, properties: half.properties, binaries)
        case "rotate":
            let picture = try load(url)
            let rotated = try rotateClockwise(picture.image)
            return try save(rotated, like: url, ext: ext, suffix: " rotated", quality: 0.9, properties: picture.properties, binaries)
        default:
            throw JobError.failed("Unknown tool \(id)")
        }
    }

    /// Every image as one page of a single PDF.
    static func combine(_ files: [URL]) throws -> URL {
        let images = try files.map { try load($0).image }
        let out = Output.free("Combined.pdf", in: files[0].deletingLastPathComponent())
        return try Output.produce(out) { try writePDF(images, to: out) }
    }

    // MARK: Reading

    /// Decoded upright (EXIF orientation applied), optionally downscaled. SVG and other AppKit-only formats fall back to NSImage.
    static func load(_ url: URL, maxPixels: Int? = nil) throws -> Picture {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
            let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
            let limit = min(maxPixels ?? Int.max, max(width, height))
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(limit, 1),
            ]
            if limit > 0, let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return Picture(image: image, properties: upright(properties))
            }
        }
        guard let image = NSImage(contentsOf: url), let rendered = render(image, maxPixels: maxPixels) else {
            throw JobError.unreadable(url.lastPathComponent)
        }
        return Picture(image: rendered, properties: [:])
    }

    private static func upright(_ properties: [CFString: Any]) -> [CFString: Any] {
        var result = properties.filter { [kCGImagePropertyExifDictionary, kCGImagePropertyGPSDictionary,
                                          kCGImagePropertyIPTCDictionary, kCGImagePropertyTIFFDictionary].contains($0.key) }
        result[kCGImagePropertyOrientation] = 1
        if var tiff = result[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            result[kCGImagePropertyTIFFDictionary] = tiff
        }
        return result
    }

    /// Vector images (SVG, PDF-backed) at 2x their point size.
    private static func render(_ image: NSImage, maxPixels: Int?) -> CGImage? {
        let scale = min(2, CGFloat(maxPixels ?? .max) / max(image.size.width, image.size.height, 1))
        let width = Int(image.size.width * scale), height = Int(image.size.height * scale)
        guard width > 0, height > 0, let context = bitmap(width: width, height: height) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    // MARK: Writing

    private static func save(_ image: CGImage, like url: URL, ext: String, suffix: String, quality: Double,
                             properties: [CFString: Any], _ binaries: Binaries) throws -> URL {
        let out = Output.beside(url, ext: ext, suffix: suffix)
        return try Output.produce(out) {
            try write(image, ext: ext, to: out, quality: quality, properties: properties, binaries: binaries)
        }
    }

    static func write(_ image: CGImage, ext: String, to out: URL, quality: Double,
                      properties: [CFString: Any] = [:], binaries: Binaries) throws {
        if ext == "webp" { return try writeWebP(image, to: out, quality: quality, binaries: binaries) }
        guard let type = types[ext],
              let destination = CGImageDestinationCreateWithURL(out as CFURL, type.identifier as CFString, 1, nil)
        else { throw JobError.failed("Can't write \(ext.uppercased())") }
        var options = properties
        options[kCGImageDestinationLossyCompressionQuality] = quality
        // JPG and BMP have no alpha: put transparent areas on white instead of black.
        options[kCGImageDestinationBackgroundColor] = CGColor(gray: 1, alpha: 1)
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw JobError.failed("Couldn't save \(out.lastPathComponent)") }
    }

    private static func writeWebP(_ image: CGImage, to out: URL, quality: Double, binaries: Binaries) throws {
        try Output.withScratch { scratch in
            let png = scratch.appendingPathComponent("frame.png")
            try write(image, ext: "png", to: png, quality: 1, binaries: binaries)
            let q = String(Int(quality * 100))
            if let cwebp = binaries.cwebp {
                try Shell.run(cwebp, ["-quiet", "-q", q, png.path, "-o", out.path])
            } else if let ffmpeg = binaries.ffmpeg {
                try Shell.run(ffmpeg, ["-hide_banner", "-loglevel", "error", "-nostdin", "-n", "-i", png.path, "-quality", q, out.path])
            } else {
                throw JobError.failed("WebP needs cwebp or ffmpeg (brew install webp)")
            }
        }
    }

    /// One page per image, sized at 144 dpi so phone photos make sensible pages.
    static func writePDF(_ images: [CGImage], to out: URL) throws {
        guard let context = CGContext(out as CFURL, mediaBox: nil, nil) else { throw JobError.failed("Couldn't create PDF") }
        for image in images {
            var box = CGRect(x: 0, y: 0, width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
            context.beginPage(mediaBox: &box)
            context.draw(image, in: box)
            context.endPage()
        }
        context.closePDF()
    }

    private static func rotateClockwise(_ image: CGImage) throws -> CGImage {
        guard let context = bitmap(width: image.height, height: image.width) else { throw JobError.failed("Out of memory") }
        context.translateBy(x: 0, y: CGFloat(image.width))
        context.rotate(by: -.pi / 2)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let rotated = context.makeImage() else { throw JobError.failed("Couldn't rotate") }
        return rotated
    }

    static func bitmap(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}

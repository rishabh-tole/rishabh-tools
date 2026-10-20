import AppKit
import PDFKit

/// PDFs through PDFKit: pages to images at 300 DPI, text out, and compress / split / merge.
enum PDFEngine {
    private static let dpi: CGFloat = 300

    static func convert(_ url: URL, to ext: String) throws -> URL {
        let document = try open(url)
        switch ext {
        case "jpg", "png": return try images(document, from: url, ext: ext)
        case "txt":
            let out = Output.beside(url, ext: ext)
            return try Output.produce(out) { try (document.string ?? "").write(to: out, atomically: true, encoding: .utf8) }
        default:
            let text = NSMutableAttributedString()
            for page in pages(document) {
                if let content = page.attributedString { text.append(content) }
                text.append(NSAttributedString(string: "\n"))
            }
            let out = Output.beside(url, ext: ext)
            return try Output.produce(out) { try DocEngine.write(text, ext: ext, to: out) }
        }
    }

    static func tool(_ id: String, _ url: URL) throws -> URL {
        let document = try open(url)
        switch id {
        case "compress":
            let out = Output.beside(url, ext: "pdf", suffix: " compressed")
            let options: [PDFDocumentWriteOption: Any] = [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true]
            return try Output.produce(out) {
                guard document.write(to: out, withOptions: options) else { throw JobError.failed("Couldn't compress") }
            }
        case "split":
            let folder = Output.beside(url, ext: "", suffix: " pages")
            return try Output.produce(folder) {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                for (index, page) in pages(document).enumerated() {
                    let single = PDFDocument()
                    guard let copy = page.copy() as? PDFPage else { continue }
                    single.insert(copy, at: 0)
                    single.write(to: folder.appendingPathComponent("page \(index + 1).pdf"))
                }
            }
        default:
            throw JobError.failed("Unknown tool \(id)")
        }
    }

    static func merge(_ files: [URL]) throws -> URL {
        let merged = PDFDocument()
        for url in files {
            for page in pages(try open(url)) {
                guard let copy = page.copy() as? PDFPage else { continue }
                merged.insert(copy, at: merged.pageCount)
            }
        }
        let out = Output.free("Merged.pdf", in: files[0].deletingLastPathComponent())
        return try Output.produce(out) {
            guard merged.write(to: out) else { throw JobError.failed("Couldn't save Merged.pdf") }
        }
    }

    private static func open(_ url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else { throw JobError.unreadable(url.lastPathComponent) }
        guard !document.isLocked else { throw JobError.failed("\(url.lastPathComponent) is password protected") }
        return document
    }

    private static func pages(_ document: PDFDocument) -> [PDFPage] {
        (0..<document.pageCount).compactMap(document.page(at:))
    }

    /// One page → `name.png`; more → a `name` folder with `page 1.png`, `page 2.png`...
    private static func images(_ document: PDFDocument, from url: URL, ext: String) throws -> URL {
        let all = pages(document)
        let binaries = Binaries(ffmpeg: nil, cwebp: nil)
        if all.count == 1 {
            let out = Output.beside(url, ext: ext)
            return try Output.produce(out) { try ImageEngine.write(try raster(all[0]), ext: ext, to: out, quality: 0.9, binaries: binaries) }
        }
        let folder = Output.beside(url, ext: "")
        return try Output.produce(folder) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            for (index, page) in all.enumerated() {
                let file = folder.appendingPathComponent("page \(index + 1).\(ext)")
                try ImageEngine.write(try raster(page), ext: ext, to: file, quality: 0.9, binaries: binaries)
            }
        }
    }

    private static func raster(_ page: PDFPage) throws -> CGImage {
        let box = page.bounds(for: .mediaBox)
        let turned = page.rotation % 180 != 0
        let scale = dpi / 72
        let width = Int((turned ? box.height : box.width) * scale), height = Int((turned ? box.width : box.height) * scale)
        guard let context = ImageEngine.bitmap(width: width, height: height) else { throw JobError.failed("Page too large") }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else { throw JobError.failed("Couldn't render page") }
        return image
    }
}

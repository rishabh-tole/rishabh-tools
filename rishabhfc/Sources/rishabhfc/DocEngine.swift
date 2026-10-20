import AppKit
import PDFKit
import RishabhFCCore

/// Rich text through NSAttributedString, which reads and writes DOCX, ODT, RTF and HTML natively.
enum DocEngine {
    private static let writers: [String: NSAttributedString.DocumentType] = [
        "docx": .officeOpenXML, "odt": .openDocument, "rtf": .rtf, "html": .html,
    ]
    private static let font = NSFont(name: "Helvetica", size: 12) ?? .systemFont(ofSize: 12)

    static func convert(_ url: URL, to ext: String) throws -> URL {
        let text = try read(url)
        let out = Output.beside(url, ext: ext)
        return try Output.produce(out) { try write(text, ext: ext, to: out) }
    }

    static func read(_ url: URL) throws -> NSAttributedString {
        switch Catalog.normalizedExtension(of: url.lastPathComponent) {
        case "txt": return plain(try TextEngine.string(url))
        case "md":
            let markdown = try TextEngine.string(url)
            let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            guard let parsed = try? AttributedString(markdown: markdown, options: options) else { return plain(markdown) }
            let text = NSMutableAttributedString(parsed)
            text.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.length))
            return text
        default:
            do { return try NSAttributedString(url: url, options: [:], documentAttributes: nil) }
            catch { throw JobError.unreadable(url.lastPathComponent) }
        }
    }

    static func write(_ text: NSAttributedString, ext: String, to out: URL) throws {
        if ext == "txt" { return try text.string.write(to: out, atomically: true, encoding: .utf8) }
        if ext == "pdf" { return try writePDF(text, to: out) }
        guard let type = writers[ext] else { throw JobError.failed("Can't write \(ext.uppercased())") }
        let range = NSRange(location: 0, length: text.length)
        try text.data(from: range, documentAttributes: [.documentType: type]).write(to: out)
    }

    private static func plain(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: NSColor.black])
    }

    /// US Letter with 0.75" margins, paginated by the print system.
    private static func writePDF(_ text: NSAttributedString, to out: URL) throws {
        try onMain {
            let info = NSPrintInfo(dictionary: [.jobSavingURL: out])
            info.jobDisposition = .save
            info.paperSize = NSSize(width: 612, height: 792)
            [\NSPrintInfo.topMargin, \.bottomMargin, \.leftMargin, \.rightMargin].forEach { info[keyPath: $0] = 54 }
            info.horizontalPagination = .fit
            info.verticalPagination = .automatic
            info.isVerticallyCentered = false
            let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 612 - 108, height: 1))
            view.appearance = NSAppearance(named: .aqua)
            view.textStorage?.setAttributedString(text)
            view.isVerticallyResizable = true
            view.sizeToFit()
            let operation = NSPrintOperation(view: view, printInfo: info)
            operation.showsPrintPanel = false
            operation.showsProgressPanel = false
            guard operation.run() else { throw JobError.failed("Couldn't create PDF") }
        }
    }
}

/// CSV/TSV tables and SRT/VTT subtitles.
enum TextEngine {
    static func convert(_ url: URL, to ext: String) throws -> URL {
        let source = Catalog.normalizedExtension(of: url.lastPathComponent)
        let text = try string(url)
        let converted: String
        switch (source, ext) {
        case ("csv", "tsv"): converted = TextConvert.csvToTSV(text)
        case ("tsv", "csv"): converted = TextConvert.tsvToCSV(text)
        case ("srt", "vtt"): converted = TextConvert.srtToVTT(text)
        case ("vtt", "srt"): converted = TextConvert.vttToSRT(text)
        case (_, "txt"): converted = TextConvert.subtitleText(text)
        default: throw JobError.failed("Can't convert \(source.uppercased()) to \(ext.uppercased())")
        }
        let out = Output.beside(url, ext: ext)
        return try Output.produce(out) { try converted.write(to: out, atomically: true, encoding: .utf8) }
    }

    /// UTF-8, falling back to Latin-1 for older exports.
    static func string(_ url: URL) throws -> String {
        guard let data = try? Data(contentsOf: url) else { throw JobError.unreadable(url.lastPathComponent) }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}

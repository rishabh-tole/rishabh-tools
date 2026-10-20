import Foundation

/// Plain-text conversions: CSV/TSV tables and SRT/VTT subtitles.
public enum TextConvert {
    // MARK: Tables

    /// RFC 4180-style parsing: quoted fields may hold commas, doubled quotes and newlines.
    public static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))[...]
        while let c = chars.popFirst() {
            if quoted {
                if c == "\"", chars.first == "\"" { field.append("\""); chars.removeFirst() }
                else if c == "\"" { quoted = false }
                else { field.append(c) }
            } else if c == "\"" { quoted = true }
            else if c == "," { row.append(field); field = "" }
            else if c == "\n" { rows.append(row + [field]); row = []; field = "" }
            else { field.append(c) }
        }
        if !field.isEmpty || !row.isEmpty { rows.append(row + [field]) }
        return rows
    }

    public static func csvToTSV(_ text: String) -> String {
        let clean: (String) -> String = { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
        return parseCSV(text).map { $0.map(clean).joined(separator: "\t") + "\n" }.joined()
    }

    public static func tsvToCSV(_ text: String) -> String {
        let quote: (String) -> String = { field in
            guard field.contains(where: { ",\"\n".contains($0) }) else { return field }
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return lines(text).map { $0.components(separatedBy: "\t").map(quote).joined(separator: ",") + "\n" }.joined()
    }

    // MARK: Subtitles

    struct Cue { let timing: String; let text: [String] }

    public static func srtToVTT(_ text: String) -> String {
        let body = cues(text).map { cue in
            ([cue.timing.replacingOccurrences(of: ",", with: ".")] + cue.text).joined(separator: "\n") + "\n"
        }
        return "WEBVTT\n\n" + body.joined(separator: "\n")
    }

    public static func vttToSRT(_ text: String) -> String {
        cues(text).enumerated().map { index, cue in
            let timing = srtTiming(cue.timing)
            return (["\(index + 1)", timing] + cue.text).joined(separator: "\n") + "\n"
        }.joined(separator: "\n")
    }

    /// Only the spoken lines, tags stripped.
    public static func subtitleText(_ text: String) -> String {
        cues(text).flatMap(\.text).map {
            $0.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }.joined(separator: "\n") + "\n"
    }

    /// Cue blocks with a timing line; drops headers, NOTE/STYLE blocks and cue ids.
    static func cues(_ text: String) -> [Cue] {
        blocks(text).compactMap { block in
            guard let timingIndex = block.firstIndex(where: { $0.contains("-->") }) else { return nil }
            return Cue(timing: block[timingIndex], text: Array(block[(timingIndex + 1)...]))
        }
    }

    /// `00:01.000 --> 00:02.500 align:start` → `00:00:01,000 --> 00:00:02,500`.
    static func srtTiming(_ timing: String) -> String {
        let parts = timing.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
        let stamp: (String) -> String = { raw in
            let time = raw.split(separator: " ").first.map(String.init) ?? raw
            let full = time.split(separator: ":").count == 2 ? "00:" + time : time
            return full.replacingOccurrences(of: ".", with: ",")
        }
        return parts.prefix(2).map(stamp).joined(separator: " --> ")
    }

    private static func blocks(_ text: String) -> [[String]] {
        lines(text).split(separator: "", omittingEmptySubsequences: true).map(Array.init)
    }

    private static func lines(_ text: String) -> [String] {
        let all = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        return all.last == "" ? Array(all.dropLast()) : all
    }
}

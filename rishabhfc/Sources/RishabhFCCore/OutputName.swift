import Foundation

/// Names for converted copies. Outputs go beside the source and never overwrite anything.
public enum OutputName {
    /// Name without its extension; `.tar.gz` counts as one extension.
    public static func base(of name: String) -> String {
        if name.lowercased().hasSuffix(".tar.gz") { return String(name.dropLast(7)) }
        return (name as NSString).deletingPathExtension
    }

    /// `base.ext` in `directory`, or `base 2.ext`, `base 3.ext`... like Finder's duplicates.
    /// An empty `ext` names a folder.
    public static func unique(in directory: URL, base: String, ext: String, exists: (URL) -> Bool) -> URL {
        let name: (String) -> String = { ext.isEmpty ? $0 : "\($0).\(ext)" }
        let first = directory.appendingPathComponent(name(base))
        guard exists(first) else { return first }
        return (2...).lazy
            .map { directory.appendingPathComponent(name("\(base) \($0)")) }
            .first { !exists($0) }!
    }
}

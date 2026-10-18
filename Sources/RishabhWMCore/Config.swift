public struct Config: Equatable {
    /// bundle id -> workspace name
    public let appWorkspaces: [String: String]
    public let floatingApps: Set<String>
    public let layout: LayoutSettings

    public init(appWorkspaces: [String: String], floatingApps: Set<String>, layout: LayoutSettings) {
        self.appWorkspaces = appWorkspaces
        self.floatingApps = floatingApps
        self.layout = layout
    }

    public static let empty = Config(appWorkspaces: [:], floatingApps: [], layout: .default)
}

public struct ConfigError: Error, Equatable, CustomStringConvertible {
    public let line: Int
    public let message: String

    public init(line: Int, message: String) {
        self.line = line
        self.message = message
    }

    public var description: String { "config line \(line): \(message)" }
}

/// Parses the small TOML subset rishabhwm uses:
///
///     [apps]
///     "com.anthropic.claudefordesktop" = "C"
///     [floating]
///     "com.docker.docker" = true
///     [layout]
///     inner-gap = 0
///     outer-gap = 0
///     accordion-padding = 30
public enum ConfigParser {
    public static func parse(_ text: String, workspaceNames: [String] = Keymap.workspaceNames) -> Result<Config, ConfigError> {
        let entries = text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            .map { (number: $0.offset + 1, text: stripComment(String($0.element)).trimmingWhitespace) }
            .filter { !$0.text.isEmpty }

        var section = ""
        var apps: [String: String] = [:]
        var floating: Set<String> = []
        var gaps: [String: Double] = [:]

        for entry in entries {
            if entry.text.hasPrefix("[") {
                guard entry.text.hasSuffix("]") else { return .failure(ConfigError(line: entry.number, message: "bad section header")) }
                section = String(entry.text.dropFirst().dropLast()).trimmingWhitespace
                guard ["apps", "floating", "layout"].contains(section) else {
                    return .failure(ConfigError(line: entry.number, message: "unknown section [\(section)]"))
                }
                continue
            }
            guard let (key, value) = splitPair(entry.text) else {
                return .failure(ConfigError(line: entry.number, message: "expected key = value"))
            }
            switch section {
            case "apps":
                let name = unquote(value).uppercased()
                guard workspaceNames.contains(name) else {
                    return .failure(ConfigError(line: entry.number, message: "unknown workspace \"\(name)\""))
                }
                apps[unquote(key)] = name
            case "floating":
                guard value == "true" || value == "false" else {
                    return .failure(ConfigError(line: entry.number, message: "floating value must be true or false"))
                }
                if value == "true" { floating.insert(unquote(key)) }
            case "layout":
                guard ["inner-gap", "outer-gap", "accordion-padding"].contains(key) else {
                    return .failure(ConfigError(line: entry.number, message: "unknown layout key \(key)"))
                }
                guard let number = Double(value), number >= 0 else {
                    return .failure(ConfigError(line: entry.number, message: "\(key) must be a number >= 0"))
                }
                gaps[key] = number
            default:
                return .failure(ConfigError(line: entry.number, message: "entry outside a section"))
            }
        }

        let layout = LayoutSettings(
            innerGap: gaps["inner-gap"] ?? 0,
            outerGap: gaps["outer-gap"] ?? 0,
            accordionPadding: gaps["accordion-padding"] ?? 30
        )
        return .success(Config(appWorkspaces: apps, floatingApps: floating, layout: layout))
    }

    private static func stripComment(_ line: String) -> String {
        var inQuotes = false
        for (index, char) in line.enumerated() {
            if char == "\"" { inQuotes.toggle() }
            if char == "#" && !inQuotes { return String(line.prefix(index)) }
        }
        return line
    }

    private static func splitPair(_ line: String) -> (String, String)? {
        var inQuotes = false
        for (index, char) in line.enumerated() {
            if char == "\"" { inQuotes.toggle() }
            if char == "=" && !inQuotes {
                let key = String(line.prefix(index)).trimmingWhitespace
                let value = String(line.dropFirst(index + 1)).trimmingWhitespace
                return key.isEmpty || value.isEmpty ? nil : (key, value)
            }
        }
        return nil
    }

    private static func unquote(_ text: String) -> String {
        text.count >= 2 && text.hasPrefix("\"") && text.hasSuffix("\"") ? String(text.dropFirst().dropLast()) : text
    }
}

extension String {
    var trimmingWhitespace: String {
        let scalars = unicodeScalars
        guard let start = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let end = scalars.lastIndex(where: { !$0.properties.isWhitespace })
        else { return "" }
        return String(scalars[start...end])
    }
}

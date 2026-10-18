import Foundation
import RishabhWMCore

/// ~/.config/rishabhwm/config.toml, created with sensible defaults on first launch.
enum ConfigStore {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/rishabhwm/config.toml")

    static let defaultText = """
    # rishabhwm config. Reload: menu bar → Reload Config, or ⌥⇧; then Esc.
    # Find an app's bundle id:  osascript -e 'id of app "Claude"'

    # Apps that always open on a workspace (1-9, A-Z except F H J K L).
    [apps]
    "com.anthropic.claudefordesktop" = "C"
    "com.google.Chrome" = "B"
    "com.microsoft.VSCode" = "E"
    "net.kovidgoyal.kitty" = "T"
    "com.hnc.Discord" = "D"
    "com.google.android.studio" = "A"

    # Apps that float instead of tiling.
    [floating]
    "com.docker.docker" = true
    "com.apple.systempreferences" = true

    [layout]
    inner-gap = 0
    outer-gap = 0
    accordion-padding = 30
    """

    static func load() -> Result<Config, ConfigError> {
        if !FileManager.default.fileExists(atPath: url.path) {
            writeDefault()
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return .failure(ConfigError(line: 0, message: "cannot read \(url.path)"))
        }
        return ConfigParser.parse(text)
    }

    private static func writeDefault() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try defaultText.write(to: url, atomically: true, encoding: .utf8)
            Log.info("wrote default config to \(url.path)")
        } catch {
            Log.error("could not write default config: \(error)")
        }
    }
}

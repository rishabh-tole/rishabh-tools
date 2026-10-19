/// Renders a Config back to the TOML subset `ConfigParser` reads (used by the settings window).
public enum ConfigWriter {
    public static func render(_ config: Config) -> String {
        let apps = config.appWorkspaces.sorted { $0.key < $1.key }.map { "\(quote($0.key)) = \(quote($0.value))" }
        let floating = config.floatingApps.sorted().map { "\(quote($0)) = true" }
        let monitors = config.monitorAssignments.sorted { $0.key < $1.key }.map { "\(quote($0.key)) = \(quote($0.value.rawValue))" }
        let layout = config.layout
        let sections: [[String]] = [
            ["# rishabhwm config. Written by the settings window; hand edits are fine too.",
             "# Reload: menu bar → Reload Config, or ⌥⇧; then Esc."],
            ["# Apps that always open on a workspace (1-9, A-Z except F H J K L).", "[apps]"] + apps,
            ["# Apps that float instead of tiling.", "[floating]"] + floating,
            ["[layout]",
             "inner-gap = \(number(layout.innerGap))",
             "outer-gap = \(number(layout.outerGap))",
             "accordion-padding = \(number(layout.accordionPadding))"],
            ["[behavior]", "focus-wrap = \(layout.wrapFocus)"],
            ["# Workspaces pinned to a display: main, secondary, builtin or external.", "[monitors]"] + monitors,
        ]
        return sections.map { $0.joined(separator: "\n") }.joined(separator: "\n\n") + "\n"
    }

    private static func quote(_ text: String) -> String {
        "\"" + text.filter { $0 != "\"" && $0 != "\n" } + "\""
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

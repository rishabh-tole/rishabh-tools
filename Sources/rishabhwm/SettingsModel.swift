import AppKit
import RishabhWMCore

/// Editable copy of the Config behind the settings window.
final class SettingsModel: ObservableObject {
    struct AppRule: Identifiable {
        let id = UUID()
        var bundleID: String
        /// "" means no workspace rule (only floating).
        var workspace: String
        var floating: Bool
    }

    struct Pin: Identifiable {
        let id = UUID()
        var workspace: String
        var role: MonitorRole
    }

    @Published var innerGap: Double
    @Published var outerGap: Double
    @Published var accordionPadding: Double
    @Published var wrapFocus: Bool
    @Published var apps: [AppRule]
    @Published var pins: [Pin]
    @Published var message: String?

    init(_ config: Config) {
        innerGap = config.layout.innerGap
        outerGap = config.layout.outerGap
        accordionPadding = config.layout.accordionPadding
        wrapFocus = config.layout.wrapFocus
        let bundles = Set(config.appWorkspaces.keys).union(config.floatingApps).sorted()
        apps = bundles.map {
            AppRule(bundleID: $0, workspace: config.appWorkspaces[$0] ?? "", floating: config.floatingApps.contains($0))
        }
        pins = config.monitorAssignments.sorted { $0.key < $1.key }.map { Pin(workspace: $0.key, role: $0.value) }
    }

    /// Builds a Config, or explains what's wrong.
    func config() -> Result<Config, ConfigError> {
        let rules = apps
            .map { AppRule(bundleID: $0.bundleID.trimmingCharacters(in: .whitespaces), workspace: $0.workspace, floating: $0.floating) }
            .filter { !$0.bundleID.isEmpty }
        let bundles = rules.map(\.bundleID)
        if let duplicate = bundles.first(where: { id in bundles.filter { $0 == id }.count > 1 }) {
            return .failure(ConfigError(line: 0, message: "\(duplicate) is listed twice"))
        }
        let workspaces = pins.map(\.workspace)
        if let duplicate = workspaces.first(where: { name in workspaces.filter { $0 == name }.count > 1 }) {
            return .failure(ConfigError(line: 0, message: "workspace \(duplicate) is pinned twice"))
        }
        let appWorkspaces = Dictionary(
            rules.filter { !$0.workspace.isEmpty }.map { ($0.bundleID, $0.workspace) },
            uniquingKeysWith: { first, _ in first }
        )
        let layout = LayoutSettings(
            innerGap: max(0, innerGap),
            outerGap: max(0, outerGap),
            accordionPadding: max(0, accordionPadding),
            wrapFocus: wrapFocus
        )
        return .success(Config(
            appWorkspaces: appWorkspaces,
            floatingApps: Set(rules.filter(\.floating).map(\.bundleID)),
            layout: layout,
            monitorAssignments: Dictionary(pins.map { ($0.workspace, $0.role) }, uniquingKeysWith: { first, _ in first })
        ))
    }

    func addApp(_ bundleID: String = "") {
        guard bundleID.isEmpty || !apps.contains(where: { $0.bundleID == bundleID }) else { return }
        apps.append(AppRule(bundleID: bundleID, workspace: "", floating: false))
    }

    func addPin() {
        let free = Keymap.workspaceNames.first { name in !pins.contains { $0.workspace == name } } ?? "1"
        pins.append(Pin(workspace: free, role: .main))
    }

    static func runningApps() -> [(name: String, bundleID: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in app.bundleIdentifier.map { (app.localizedName ?? $0, $0) } }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

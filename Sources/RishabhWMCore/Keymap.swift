public struct KeyCombo: Hashable {
    /// Key name: "a"..."z", "0"..."9", "minus", "equal", "slash", "comma", "semicolon",
    /// "tab", "escape", "backspace".
    public let key: String
    public let option: Bool
    public let shift: Bool

    public init(_ key: String, option: Bool = true, shift: Bool = false) {
        self.key = key
        self.option = option
        self.shift = shift
    }

    public var label: String { (option ? "⌥" : "") + (shift ? "⇧" : "") + key }
}

public enum Action: Equatable {
    case command(Command)
    case enterServiceMode
    case reloadConfig
    case closeAllButCurrent
}

public struct Binding: Equatable {
    public let combo: KeyCombo
    public let action: Action
    /// Service-mode bindings drop back to main mode after running.
    public let exitsServiceMode: Bool

    public init(_ combo: KeyCombo, _ action: Action, exitsServiceMode: Bool = false) {
        self.combo = combo
        self.action = action
        self.exitsServiceMode = exitsServiceMode
    }
}

/// AeroSpace default bindings. ⌥F is fullscreen and ⌥⇧F float, so there is no workspace F.
public enum Keymap {
    public static let workspaceNames: [String] =
        (1...9).map(String.init) + "ABCDEGIMNOPQRSTUVWXYZ".map { String($0) }

    private static let directionKeys: [(String, Direction)] = [
        ("h", .left), ("j", .down), ("k", .up), ("l", .right),
    ]

    public static let main: [Binding] = {
        let focus = directionKeys.map { Binding(KeyCombo($0.0), .command(.focus($0.1))) }
        let move = directionKeys.map { Binding(KeyCombo($0.0, shift: true), .command(.move($0.1))) }
        let workspaces = workspaceNames.flatMap { name -> [Binding] in
            let key = name.lowercased()
            return [
                Binding(KeyCombo(key), .command(.workspace(name))),
                Binding(KeyCombo(key, shift: true), .command(.moveToWorkspace(name))),
            ]
        }
        let misc: [Binding] = [
            Binding(KeyCombo("minus"), .command(.resize(-50))),
            Binding(KeyCombo("equal"), .command(.resize(50))),
            Binding(KeyCombo("slash"), .command(.layoutTiles)),
            Binding(KeyCombo("comma"), .command(.layoutAccordion)),
            Binding(KeyCombo("f"), .command(.fullscreen)),
            Binding(KeyCombo("f", shift: true), .command(.toggleFloat)),
            Binding(KeyCombo("tab"), .command(.workspaceBackAndForth)),
            Binding(KeyCombo("tab", shift: true), .command(.moveWorkspaceToNextMonitor)),
            Binding(KeyCombo("semicolon", shift: true), .enterServiceMode),
        ]
        return focus + move + workspaces + misc
    }()

    public static let service: [Binding] = {
        let join = directionKeys.map {
            Binding(KeyCombo($0.0, shift: true), .command(.joinWith($0.1)), exitsServiceMode: true)
        }
        return join + [
            Binding(KeyCombo("escape", option: false), .reloadConfig, exitsServiceMode: true),
            Binding(KeyCombo("r", option: false), .command(.flatten), exitsServiceMode: true),
            Binding(KeyCombo("f", option: false), .command(.toggleFloat), exitsServiceMode: true),
            Binding(KeyCombo("backspace", option: false), .closeAllButCurrent, exitsServiceMode: true),
        ]
    }()
}

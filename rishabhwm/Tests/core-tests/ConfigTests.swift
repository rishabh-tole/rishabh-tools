import RishabhWMCore

func configTests() {
    test("parses apps, floating and layout") {
        let text = """
        # comment
        [apps]
        "com.anthropic.claudefordesktop" = "c"   # Claude
        "com.google.Chrome" = "B"

        [floating]
        "com.docker.docker" = true
        "com.apple.finder" = false

        [layout]
        inner-gap = 8
        accordion-padding = 20
        """
        guard case .success(let config) = ConfigParser.parse(text) else { return expect(false, "should parse") }
        expectEqual(config.appWorkspaces["com.anthropic.claudefordesktop"], "C")
        expectEqual(config.appWorkspaces["com.google.Chrome"], "B")
        expectEqual(config.floatingApps, ["com.docker.docker"])
        expectEqual(config.layout, LayoutSettings(innerGap: 8, outerGap: 0, accordionPadding: 20))
    }

    test("rejects unknown workspace with line number") {
        let result = ConfigParser.parse("[apps]\n\"x\" = \"F\"")
        expectEqual(result, .failure(ConfigError(line: 2, message: "unknown workspace \"F\"")))
    }

    test("rejects junk") {
        if case .success = ConfigParser.parse("[nope]") { expect(false, "unknown section") }
        if case .success = ConfigParser.parse("[layout]\ninner-gap = -1") { expect(false, "negative gap") }
        if case .success = ConfigParser.parse("hello") { expect(false, "no section") }
    }

    test("parses behavior and monitors") {
        let text = "[behavior]\nfocus-wrap = false\n[monitors]\n\"c\" = \"Builtin\"\n\"1\" = \"main\""
        guard case .success(let config) = ConfigParser.parse(text) else { return expect(false, "should parse") }
        expectEqual(config.layout.wrapFocus, false)
        expectEqual(config.monitorAssignments, ["C": .builtin, "1": .main])
        if case .success = ConfigParser.parse("[monitors]\n\"C\" = \"left\"") { expect(false, "bad role") }
    }

    test("writer round-trips through the parser") {
        let config = Config(
            appWorkspaces: ["com.google.Chrome": "B", "net.kovidgoyal.kitty": "T"],
            floatingApps: ["com.docker.docker"],
            layout: LayoutSettings(innerGap: 8, outerGap: 4.5, accordionPadding: 30, wrapFocus: false),
            monitorAssignments: ["C": .main]
        )
        expectEqual(ConfigParser.parse(ConfigWriter.render(config)), .success(config))
    }

    test("keymap has AeroSpace bindings and no conflicts") {
        let combos = Keymap.main.map(\.combo)
        expectEqual(Set(combos).count, combos.count)
        expect(Keymap.main.contains(Binding(KeyCombo("c"), .command(.workspace("C")))))
        expect(Keymap.main.contains(Binding(KeyCombo("c", shift: true), .command(.moveToWorkspace("C")))))
        expect(!Keymap.workspaceNames.contains("H") && !Keymap.workspaceNames.contains("F"))
    }
}

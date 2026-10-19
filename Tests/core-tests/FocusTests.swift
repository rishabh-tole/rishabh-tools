import RishabhWMCore

private let laptop = Screen(id: "laptop", frame: Rect(x: 0, y: 25, width: 1000, height: 775), isBuiltin: true)
// Main display: odd resolution, to the left of the laptop and taller.
private let ultrawide = Screen(id: "ultrawide", frame: Rect(x: -3440, y: -300, width: 3440, height: 1415), isMain: true)
private let names = Keymap.workspaceNames

private func three() -> World {
    World(names: names, screens: [laptop])
        .addingWindow(1, toWorkspace: nil, floating: false)
        .addingWindow(2, toWorkspace: nil, floating: false)
        .addingWindow(3, toWorkspace: nil, floating: false)
}

private func dual() -> World {
    World(names: names, screens: [ultrawide, laptop])
        .addingWindow(1, toWorkspace: "1", floating: false)
        .addingWindow(2, toWorkspace: "1", floating: false)
        .addingWindow(3, toWorkspace: "2", floating: false)
        .focusingWindow(1)
}

func focusTests() {
    test("focus wraps around at the edge of a single display") {
        let world = three().focusingWindow(3).applying(.focus(.right))
        expectEqual(world.focused, 1)
        expectEqual(world.applying(.focus(.left)).focused, 3)
    }

    test("focus wrap can be turned off") {
        let world = three().focusingWindow(3).applying(.focus(.right), settings: LayoutSettings(wrapFocus: false))
        expectEqual(world.focused, 3)
    }

    test("fullscreen survives focus moves and the rest stays tiled underneath") {
        let world = three().focusingWindow(1).applying(.fullscreen)
        let placements = world.placements(settings: .default)
        expectEqual(placements[1], .tiled(laptop.frame))
        expectEqual(placements[2], .tiled(Rect(x: 0, y: 25, width: 500, height: 775)))
        expectEqual(placements[3], .tiled(Rect(x: 500, y: 25, width: 500, height: 775)))

        let right = world.applying(.focus(.right))
        expectEqual(right.focused, 2)
        expectEqual(right.workspace("1").fullscreen, 1)
        expectEqual(right.placements(settings: .default), placements)
        expectEqual(right.applying(.focus(.right)).applying(.focus(.right)).focused, 1)
        expectEqual(world.applying(.focus(.left)).focused, 3)
    }

    test("main display starts on workspace 1") {
        let world = World(names: names, screens: [ultrawide, laptop])
        expectEqual(world.monitors.map(\.workspace), ["1", "2"])
        let swapped = World(names: names, screens: [laptop, Screen(id: "x", frame: Rect(x: 1000, y: 0, width: 2560, height: 1080), isMain: true)])
        expectEqual(swapped.monitors.map(\.workspace), ["2", "1"])
    }

    test("focus crosses displays then wraps back around") {
        let world = dual().applying(.focus(.right))
        expectEqual(world.focused, 2)
        let crossed = world.applying(.focus(.right))
        expectEqual(crossed.focused, 3)
        expectEqual(crossed.focusedMonitor, 1)
        let wrapped = crossed.applying(.focus(.right))
        expectEqual(wrapped.focused, 1)
        expectEqual(wrapped.focusedMonitor, 0)
    }

    test("move window to the display on the right and back, wrapping") {
        let world = dual().applying(.moveToMonitor(.right))
        expectEqual(world.workspaceName(of: 1), "2")
        expectEqual(world.focusedMonitor, 1)
        expectEqual(world.focused, 1)
        let wrapped = world.applying(.moveToMonitor(.right))
        expectEqual(wrapped.workspaceName(of: 1), "1")
        expectEqual(wrapped.focusedMonitor, 0)
    }

    test("moving a fullscreen window to another display keeps it fullscreen") {
        let world = dual().applying(.fullscreen).applying(.moveToMonitor(.left))
        expectEqual(world.workspace("2").fullscreen, 1)
        expectEqual(world.workspace("1").fullscreen, nil)
        expectEqual(world.placements(settings: .default)[1], .tiled(laptop.frame))
    }

    test("focus display wraps") {
        let world = dual().applying(.focusMonitor(.left))
        expectEqual(world.focusedMonitor, 1)
        expectEqual(world.focused, 3)
        expectEqual(world.applying(.focusMonitor(.left)).focusedMonitor, 0)
    }

    test("wrapping stays in the display row: a laptop below the main display is skipped") {
        let below = Screen(id: "below", frame: Rect(x: -3440, y: 1115, width: 1512, height: 945), isBuiltin: true)
        let world = World(names: names, screens: [ultrawide, below])
            .addingWindow(1, toWorkspace: "1", floating: false)
            .addingWindow(2, toWorkspace: "1", floating: false)
            .addingWindow(3, toWorkspace: "2", floating: false)
            .focusingWindow(2)
        let wrapped = world.applying(.focus(.right))
        expectEqual(wrapped.focused, 1)
        expectEqual(wrapped.focusedMonitor, world.focusedMonitor)
        expectEqual(world.applying(.focus(.down)).focused, 3)
    }

    test("display keys still reach a display stacked below") {
        let below = Screen(id: "below", frame: Rect(x: -3440, y: 1115, width: 1512, height: 945), isBuiltin: true)
        let world = World(names: names, screens: [ultrawide, below])
            .addingWindow(1, toWorkspace: "1", floating: false)
            .focusingWindow(1)
        let moved = world.applying(.moveToMonitor(.right))
        expectEqual(moved.workspaceName(of: 1), "2")
        expectEqual(moved.applying(.focusMonitor(.left)).focusedWorkspaceName, "1")
    }

    test("no monitors does not crash") {
        let world = World(names: names, screens: [])
        expectEqual(world.applying(.focus(.right)), world)
        expectEqual(world.applying(.focusMonitor(.right)), world)
        expectEqual(world.applying(.moveToMonitor(.left)), world)
    }

    test("fullscreen toggles back into its old slot") {
        let world = three().focusingWindow(2).applying(.fullscreen).applying(.focus(.right)).applying(.focus(.left))
        expectEqual(world.focused, 2)
        let restored = world.applying(.fullscreen)
        expectEqual(restored.workspace("1").fullscreen, nil)
        expectEqual(restored.placements(settings: .default)[2], .tiled(Rect(x: 1000.0 / 3, y: 25, width: 1000.0 / 3, height: 775)))
    }

    test("pinned workspaces open on their display") {
        let world = dual().with(assignments: ["C": .builtin])
            .addingWindow(4, toWorkspace: "C", floating: false)
            .applying(.workspace("C"))
        expectEqual(world.monitors.map(\.workspace), ["1", "C"])
        expectEqual(world.focusedMonitor, 1)
        expectEqual(world.focused, 4)
    }

    test("floating frame keeps its relative spot on another display") {
        let rect = Rect(x: 100, y: 100, width: 400, height: 300)
        let moved = rect.moved(from: Rect(x: 0, y: 0, width: 1000, height: 1000), to: Rect(x: 2000, y: 0, width: 300, height: 1000))
        expectEqual(moved.width, 300)
        expectEqual(moved.x, 2000)
    }
}

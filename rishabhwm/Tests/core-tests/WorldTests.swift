import RishabhWMCore

private let laptop = Screen(id: "laptop", frame: Rect(x: 0, y: 25, width: 1000, height: 775))
private let external = Screen(id: "external", frame: Rect(x: 1000, y: 0, width: 2000, height: 1200))
private let names = Keymap.workspaceNames

private func oneMonitor() -> World { World(names: names, screens: [laptop]) }

private func populated() -> World {
    oneMonitor()
        .addingWindow(1, toWorkspace: nil, floating: false)
        .addingWindow(2, toWorkspace: nil, floating: false)
        .addingWindow(3, toWorkspace: "C", floating: false)
        .focusingWindow(2)
}

func worldTests() {
    test("new windows land on the focused workspace or their rule workspace") {
        let world = populated()
        expectEqual(world.workspaceName(of: 1), "1")
        expectEqual(world.workspaceName(of: 3), "C")
        expectEqual(world.focusedWorkspaceName, "1")
    }

    test("hidden workspace windows are parked") {
        let placements = populated().placements(settings: .default)
        expectEqual(placements[3], .hidden)
        expectEqual(placements[1], .tiled(Rect(x: 0, y: 25, width: 500, height: 775)))
    }

    test("switching workspace shows it and focuses its last window") {
        let world = populated().applying(.workspace("C"))
        expectEqual(world.focusedWorkspaceName, "C")
        expectEqual(world.focused, 3)
        expectEqual(world.previousWorkspace, "1")
        expectEqual(world.placements(settings: .default)[1], .hidden)
    }

    test("switching to an empty workspace clears focus") {
        let world = populated().applying(.workspace("B"))
        expectEqual(world.focusedWorkspaceName, "B")
        expectEqual(world.focused, nil)
    }

    test("back and forth") {
        let world = populated().applying(.workspace("C")).applying(.workspaceBackAndForth)
        expectEqual(world.focusedWorkspaceName, "1")
        expectEqual(world.focused, 2)
    }

    test("send window to workspace keeps you where you are") {
        let world = populated().applying(.moveToWorkspace("C"))
        expectEqual(world.workspaceName(of: 2), "C")
        expectEqual(world.focusedWorkspaceName, "1")
        expectEqual(world.focused, 1)
        let jumped = world.applying(.workspace("C"))
        expectEqual(jumped.focused, 2)
    }

    test("focusing a window on a hidden workspace switches to it") {
        let world = populated().focusingWindow(3)
        expectEqual(world.focusedWorkspaceName, "C")
        expectEqual(world.previousWorkspace, "1")
    }

    test("closing the focused window falls back to a neighbor") {
        let world = populated().removingWindow(2)
        expectEqual(world.focused, 1)
        expectEqual(world.workspaceName(of: 2), nil)
    }

    test("focus direction within workspace") {
        let world = populated().applying(.focus(.left))
        expectEqual(world.focused, 1)
    }

    test("float toggle takes window out of tiling") {
        let world = populated().applying(.toggleFloat)
        expectEqual(world.placements(settings: .default)[2], .floating)
        expectEqual(world.placements(settings: .default)[1], .tiled(Rect(x: 0, y: 25, width: 1000, height: 775)))
    }

    test("fullscreen covers the monitor") {
        let world = populated().applying(.fullscreen)
        expectEqual(world.placements(settings: .default)[2], .tiled(laptop.frame))
        expectEqual(world.applying(.fullscreen).placements(settings: .default)[2], .tiled(Rect(x: 500, y: 25, width: 500, height: 775)))
    }

    test("two monitors show different workspaces") {
        let world = World(names: names, screens: [laptop, external])
            .addingWindow(1, toWorkspace: nil, floating: false)
            .addingWindow(2, toWorkspace: "2", floating: false)
        expectEqual(world.monitors.map(\.workspace), ["1", "2"])
        let placements = world.placements(settings: .default)
        expectEqual(placements[2], .tiled(external.frame))
    }

    test("switching to a workspace on the other monitor moves focus there") {
        let world = World(names: names, screens: [laptop, external])
            .addingWindow(1, toWorkspace: nil, floating: false)
            .addingWindow(2, toWorkspace: "2", floating: false)
            .focusingWindow(1)
            .applying(.workspace("2"))
        expectEqual(world.focusedMonitor, 1)
        expectEqual(world.focused, 2)
        expectEqual(world.monitors.map(\.workspace), ["1", "2"])
    }

    test("focus right crosses to the other monitor") {
        let world = World(names: names, screens: [laptop, external])
            .addingWindow(1, toWorkspace: nil, floating: false)
            .addingWindow(2, toWorkspace: "2", floating: false)
            .focusingWindow(1)
            .applying(.focus(.right))
        expectEqual(world.focused, 2)
        expectEqual(world.focusedMonitor, 1)
    }

    test("move right at edge sends window to the other monitor") {
        let world = World(names: names, screens: [laptop, external])
            .addingWindow(1, toWorkspace: nil, floating: false)
            .focusingWindow(1)
            .applying(.move(.right))
        expectEqual(world.workspaceName(of: 1), "2")
        expectEqual(world.focusedMonitor, 1)
    }

    test("unplugging a monitor keeps its windows on a hidden workspace") {
        let world = World(names: names, screens: [laptop, external])
            .addingWindow(2, toWorkspace: "2", floating: false)
            .updatingMonitors([laptop])
        expectEqual(world.monitors.map(\.workspace), ["1"])
        expectEqual(world.placements(settings: .default)[2], .hidden)
        let replugged = world.updatingMonitors([laptop, external])
        expectEqual(replugged.monitors.count, 2)
    }

    test("move workspace to next monitor") {
        let world = World(names: names, screens: [laptop, external])
            .addingWindow(1, toWorkspace: nil, floating: false)
            .focusingWindow(1)
            .applying(.moveWorkspaceToNextMonitor)
        expectEqual(world.monitors[1].workspace, "1")
        expectEqual(world.focusedMonitor, 1)
        expect(world.monitors[0].workspace != "1")
    }
}

# How it works

## Core idea

macOS has no public API for Spaces. Window managers handle that in one of two ways:

- **yabai** drives real Spaces, which requires partly disabling System Integrity Protection.
- **AeroSpace** ignores Spaces and keeps everything on one. Windows on hidden workspaces are parked in a screen corner. That conflicts with native fullscreen, because each fullscreen app gets its own Space.

rishabhwm takes AeroSpace's approach, but only on each display's **home desktop** (its first normal Space):

- Windows on the home desktop are tiled. Windows on hidden workspaces are parked in a corner with 1pt left on screen.
- Native fullscreen windows and windows on other Spaces are never tracked. They are not tiled, moved or hidden.
- The home desktop and the current Space are identified with read-only private SkyLight calls (`SLSGetActiveSpace`, `SLSCopyManagedDisplaySpaces`, `SLSCopySpacesForWindows`). These work with SIP fully enabled. If Apple removes them, rishabhwm falls back to the Accessibility `AXFullScreen` attribute.

### Fullscreen flow

```
⌥C pressed
  │
  ├─ on home desktop? ── yes ─▶ show workspace C, focus its last window
  │
  └─ no (fullscreen app in front)
        │
        ├─ only workspace keys and ⌥Tab are allowed; everything else is ignored
        ├─ show workspace C on the home desktop
        └─ focus C's last window, or the invisible "anchor" window if C is empty
             └─▶ macOS switches to the Space holding that window: the home desktop
```

The **anchors** are 1×1 transparent windows, one on each display's home desktop. Focusing one is how rishabhwm gets you out of a fullscreen app when the target workspace has no windows. It also takes keyboard focus away from windows that were just hidden.

- When a window enters native fullscreen, rishabhwm sees the Space change and forgets the window. The rest of the workspace reflows.
- When it leaves fullscreen and returns to the home desktop, a rescan adopts it again.

## Layout model

Each workspace holds a tree, like AeroSpace's:

- **Containers** have an orientation (horizontal/vertical) and a layout (tiles/accordion). Each child has a `weight` that sets its share of the container.
- **Leaves** are windows.
- Floating windows are kept in a separate list on the workspace.

After every edit, the tree is normalized:
- empty containers are dropped,
- single-child containers are flattened,
- a child container with the same orientation and layout as its parent is merged into the parent.

Commands are pure functions `World → World`:

| Command | What it does to the tree |
|---|---|
| move | Swaps with a sibling, steps into a sibling container, or pops out to the nearest ancestor running in that direction. If no ancestor runs that way, the root is wrapped in a new container. |
| focus | Climbs to the nearest ancestor with a neighbor in that direction, then picks that branch's window closest to the current one. |
| join-with | Wraps the window and its neighbor in a container of the opposite orientation. |
| resize | Changes the window's weight so its size changes by exactly N points. |

## Event handling

Nothing polls. Everything is driven by events:

| Source | Events |
|---|---|
| `AXObserver` per app | window created, focused window changed |
| `AXObserver` per window | destroyed, moved, resized, minimized |
| `NSWorkspace` | app launched / terminated / activated / hidden / unhidden, active Space changed |
| `NSApplication` | screen configuration changed |
| Carbon `RegisterEventHotKey` | hotkeys (no Input Monitoring, no event tap) |

Frames are only set when they differ from the last frame rishabhwm applied. Tiled windows dragged or resized by hand snap back once the mouse is released.

## Code map

```
Sources/RishabhWMCore/       pure Swift, no AppKit, immutable values
  Geometry.swift             Rect, Orientation, Direction
  Node.swift                 layout tree
  TreeEdit.swift             insert / remove / normalize
  TreeMoves.swift            move, join, layout toggles, resize, flatten
  TreeLayout.swift           tree -> frames (tiles, accordion, gaps)
  Navigation.swift           directional focus
  Workspace.swift            one workspace: tree + floating + focus memory
  World.swift                all workspaces + monitors
  WorldWindows.swift         window add/remove/focus, monitor changes
  Command.swift              hotkey commands as World -> World
  Placement.swift            World -> tiled / floating / hidden per window
  Keymap.swift               AeroSpace default bindings
  Config.swift               TOML-subset parser

Sources/rishabhwm/           macOS integration
  main.swift                 app delegate, permission wait, signal handling
  Controller*.swift          event handling, applying layout, hotkey actions
  AX.swift                   Accessibility wrappers
  AppObserver.swift          AXObserver per app
  SkyLight.swift             Space detection, window focus across Spaces
  HotKeys.swift              Carbon hotkeys
  Anchors.swift              invisible home-desktop windows
  Screens.swift              displays, coordinate conversion, parking spots
  StatusBar.swift            menu bar item
  ConfigStore.swift          config file location and defaults

Tests/core-tests/            unit tests for RishabhWMCore
scripts/                     build, install, uninstall, test
```

## Lifecycle

- `scripts/install.sh` builds `~/Applications/rishabhwm.app`, ad-hoc signed, as a menu-bar-only app. It also installs the LaunchAgent `com.rishabh.rishabhwm` with `RunAtLoad` and `KeepAlive { SuccessfulExit = false }`:
  - rishabhwm starts at login.
  - It restarts after a crash.
  - Quitting from the menu (a clean exit) keeps it off until next login.
- On quit, `SIGTERM`, `SIGINT` or `SIGHUP`, every parked window is moved back on screen.
- If it crashes instead, the relaunch adopts all windows again, so nothing stays lost.

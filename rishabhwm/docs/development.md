# Development

## Requirements

- macOS 14+ on Apple Silicon or Intel
- Swift 5.9+ (Xcode or Command Line Tools)

No third-party dependencies.

## Build and run

```bash
swift build                    # debug build
.build/debug/rishabhwm         # run in the foreground (stop the installed copy first)
./scripts/build-app.sh         # release .app in build/
./scripts/install.sh           # build + install + (re)start the LaunchAgent
```

`RISHABHWM_DEBUG=1` turns on debug logs: window adoption, key presses, ignored focus events.

## Tests

```bash
./scripts/test.sh              # same as: swift run core-tests
```

The tests are a plain executable (`Tests/core-tests`) with a minimal assertion helper, not XCTest. That way they run with Command Line Tools alone, since XCTest and swift-testing need a full Xcode install.

They cover everything in `RishabhWMCore`:
- tree normalization, move, join, layout toggles, resize, flatten
- layout math (tiles, accordion, gaps, weights)
- workspaces: switching, sending windows, back-and-forth, focus following, closing
- multiple monitors: cross-display focus and move, unplugging and replugging, moving workspaces
- config parsing and keymap sanity

The macOS layer (`Sources/rishabhwm`) has no automated tests: it talks to the Accessibility API and WindowServer. Check changes there by hand, using the checklist below.

## Manual test checklist

1. Two windows on a workspace tile side by side. `⌥h/l` moves focus, `⌥⇧h/l` swaps them.
2. `⌥⇧2` sends a window away. `⌥2` brings you to it, with that window focused.
3. `⌥/` flips the split; `⌥,` switches to accordion.
4. Green-button fullscreen an app: the remaining windows reflow. Swiping is smooth.
5. From the fullscreen app, `⌥C` lands on the home desktop with workspace C, including when C is empty.
6. Leave fullscreen: the window is tiled again.
7. Quit from the menu bar: every hidden window is back on screen.
8. With two displays: `⌥l` crosses to the other display, and `⌥⇧l` at the edge moves the window there.

## Design rules

- `RishabhWMCore` is pure: no AppKit, no side effects, immutable values. Every change returns a new `World`.
- The macOS layer only translates. Events go into the `World`; `world.placements(...)` comes out as frames.
- Don't add polling. React to AX, NSWorkspace and screen notifications.
- Keep files small and focused (under ~300 lines).

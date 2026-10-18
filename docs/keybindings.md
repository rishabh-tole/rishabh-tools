# Keybindings

rishabhwm uses AeroSpace's default bindings. `⌥` is the Option key.

## Main mode

### Focus and move

| Keys | Action |
|---|---|
| `⌥h` `⌥j` `⌥k` `⌥l` | Focus the window left / down / up / right. At the edge of a display, focus jumps to the neighboring display. |
| `⌥⇧h` `⌥⇧j` `⌥⇧k` `⌥⇧l` | Move the focused window. It swaps with a neighbor, steps into a neighboring column/row, or pops out of one. At the edge of a display it moves to the next display. |

### Workspaces

Workspace names are `1`–`9` and `A`–`Z` except `F` (used by fullscreen) and `H J K L` (used by focus/move).

| Keys | Action |
|---|---|
| `⌥1`…`⌥9`, `⌥a`…`⌥z` | Go to that workspace. If another display already shows it, focus moves to that display. |
| `⌥⇧1`…`⌥⇧9`, `⌥⇧a`…`⌥⇧z` | Send the focused window to that workspace. You stay where you are; jump there later with `⌥<key>` and the window is focused. |
| `⌥Tab` | Back and forth between the current and previous workspace. |
| `⌥⇧Tab` | Move the current workspace to the next display. |

### Layout

| Keys | Action |
|---|---|
| `⌥/` | Tiles layout for the focused window's container. Press again to flip horizontal ↔ vertical. |
| `⌥,` | Accordion layout: windows stacked, each nearly full size, with a 30pt peek of its neighbors. Press again to flip orientation. |
| `⌥-` / `⌥=` | Shrink / grow the focused window by 50pt along its container. |
| `⌥F` | Make the focused window fill the display (rishabhwm's fullscreen; not macOS fullscreen). Press again to put it back. |
| `⌥⇧F` | Toggle floating: take the window out of tiling, or put it back. |
| `⌥⇧;` | Enter service mode. |

## Service mode

Press `⌥⇧;`. The menu bar shows `⚙︎` until a key below runs, then you're back in main mode.

| Keys | Action |
|---|---|
| `Esc` | Reload the config file. |
| `r` | Reset the layout: every window on the workspace side by side. |
| `f` | Toggle floating. |
| `⌫` (Backspace) | Close every other window on the workspace. |
| `⌥⇧h/j/k/l` | Join the focused window with its neighbor into a new column/row. |

## From a fullscreen app

When a native fullscreen app (green button) is in front, rishabhwm doesn't touch it:

| Keys | Behavior |
|---|---|
| `⌥<workspace>` | Switches to the home desktop showing that workspace, even if it's the current one or empty. |
| `⌥Tab` | Switches to the home desktop on the previous workspace. |
| Everything else | Does nothing. |

Swiping between Spaces is never intercepted.

## Typing special characters

`⌥` + letter normally types characters like `˙` or `∆`. rishabhwm claims those combos, so they no longer type characters. If you need them, use the macOS character viewer (`⌃⌘Space`).

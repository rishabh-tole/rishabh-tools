# Configuration

rishabhwm reads `~/.config/rishabhwm/config.toml`. It creates the file with defaults on first launch.

Reload after editing, either way:
- menu bar item → **Reload Config**
- `⌥⇧;` then `Esc`

If the file has a mistake, the old config stays active. The menu bar menu then shows the error with its line number, e.g. `config line 4: unknown workspace "F"`.

## Example

```toml
# Apps that always open on a workspace.
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
inner-gap = 0          # points between tiled windows
outer-gap = 0          # points between windows and the screen edge
accordion-padding = 30 # how much of the neighbors an accordion shows

[behavior]
focus-wrap = true      # ⌥hjkl past the last window wraps around

# Workspaces pinned to a display.
[monitors]
"C" = "builtin"
```

Easier: menu bar item → **Settings…** edits all of this in a small window and saves it to the file. Saving rewrites the file, so hand-written comments are dropped.

## `[apps]`: app routing

`"<bundle id>" = "<workspace>"`. New windows of that app open on that workspace.
- Workspace names are case-insensitive: `1`–`9` and `A`–`Z` except `F H J K L`.
- When the app's new window takes focus, rishabhwm switches you to its workspace. So opening Claude takes you straight to C.

To find an app's bundle id:

```bash
osascript -e 'id of app "Claude"'
```

## `[floating]`: floating apps

`"<bundle id>" = true`. Windows of these apps are never tiled. They keep the size and position you give them. They still belong to a workspace and hide or show with it.

Dialogs, sheets, panels and other non-standard windows are always left alone, whatever this section says.

## `[layout]`

| Key | Default | Meaning |
|---|---|---|
| `inner-gap` | `0` | Gap between tiled windows, in points |
| `outer-gap` | `0` | Gap between tiled windows and the screen edge |
| `accordion-padding` | `30` | How much of each neighbor stays visible in accordion layout |

All values must be numbers `>= 0`.

## `[behavior]`

| Key | Default | Meaning |
|---|---|---|
| `focus-wrap` | `true` | `⌥hjkl` at the last window (and last display) wraps around to the opposite edge |

## `[monitors]`: pinned workspaces

`"<workspace>" = "<display>"`. When you switch to that workspace (or one of its windows takes focus) it opens on that display instead of the focused one. If no such display is connected, it opens on the focused one as usual.

| Display | Meaning |
|---|---|
| `main` | The display with the menu bar (System Settings → Displays → Use as Main display) |
| `secondary` | Any display that isn't the main one |
| `builtin` | The laptop's own screen |
| `external` | Any display that isn't the laptop screen |

## Not configurable (yet)

- **Keybindings**: they are fixed to the [AeroSpace defaults](keybindings.md).
- **Which desktop is managed**: always Desktop 1 of each display.

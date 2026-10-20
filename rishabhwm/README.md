# rishabhwm

A tiny tiling window manager for macOS, modeled on [AeroSpace](https://github.com/nikitabobko/AeroSpace), that **leaves native fullscreen apps alone**.

AeroSpace fakes workspaces on a single macOS Space, so green-button fullscreen apps and trackpad swipes between Spaces get laggy and glitchy. rishabhwm manages only each display's **home desktop** and ignores everything else. You get AeroSpace's tiling and `⌥`/`⌥⇧` workspace keys, while fullscreen apps and swipes keep working like stock macOS.

```
 home desktop (managed)                       fullscreen Spaces (untouched)
┌───────────────────────────────┐   swipe   ┌──────────────┐ ┌──────────────┐
│ workspace C  ┌───────┬──────┐ │ ◀───────▶ │ Xcode (full) │ │ Figma (full) │
│ (⌥C)         │Claude │Chrome│ │           └──────────────┘ └──────────────┘
│              └───────┴──────┘ │                  │
│ workspaces 1-9, A-Z           │ ◀── ⌥C from here pulls you home, C open
└───────────────────────────────┘
```

## Highlights

- **AeroSpace-style tiling**: tree layout, tiles and accordion, `⌥hjkl` focus, `⌥⇧hjkl` move, join, resize, float, service mode.
- **Workspaces `1–9`, `A–Z`**: `⌥<key>` to go, `⌥⇧<key>` to send a window, `⌥Tab` to go back.
- **Fullscreen-agnostic**:
  - Native fullscreen windows are never tiled, moved or hidden.
  - In a fullscreen app, `⌥C` brings you to the home desktop with workspace C open.
  - Swipe back and C is still there.
- **App routing**: Claude always opens on C, Chrome on B, and so on, set from a small TOML file.
- **Window fullscreen that doesn't fight you**: `⌥F` fills the display while the other windows keep tiling underneath. `⌥hjkl` cycles through them without retiling anything.
- **Focus wraps**: `⌥hjkl` past the last window wraps around to the opposite edge (across displays too).
- **Multi-monitor**:
  - Each display shows its own workspace. Focus and move cross displays.
  - `⌥[` / `⌥]` focus the left / right display, `⌥⇧[` / `⌥⇧]` send a window there.
  - Pin workspaces to a display (main, laptop, external...). The main display starts on workspace 1, wherever it sits.
  - Works with mismatched displays, e.g. an ultrawide main monitor next to (or above) the laptop screen.
- **Settings window**: gaps, wrapping, app rules and pinned workspaces, from the menu bar.
- **Lightweight**:
  - ~840 KB native Swift binary with no dependencies.
  - No polling: everything is event driven.
  - No Input Monitoring permission and no SIP changes.
- **Always on**: a LaunchAgent starts it at login and restarts it if it crashes.

## Install

Requires macOS 14+ and the Swift toolchain (Xcode or Command Line Tools: `xcode-select --install`).

```bash
git clone https://github.com/rishabh-tole/rishabh-tools.git
cd rishabh-tools/rishabhwm
./scripts/install.sh
```

Then allow **rishabhwm** under System Settings → Privacy & Security → **Accessibility**. Until you do, the menu bar item shows `⚠︎ wm`. Once allowed, it shows your current workspace (e.g. `C`, or `C · 2` with two displays).

The first build creates a self-signed code-signing certificate, `rishabhwm local signing`, in your login keychain. Every build is signed with it, so the Accessibility permission survives rebuilds and reinstalls: you grant it once. To update later, `git pull && ./scripts/install.sh`.

Recommended Mission Control settings (System Settings → Desktop & Dock):

| Setting | Value | Why |
|---|---|---|
| Displays have separate Spaces | On (default) | Each display gets its own home desktop |
| Automatically rearrange Spaces based on most recent use | Off | Keeps Desktop 1 first |
| Desktops per display | One | rishabhwm manages Desktop 1 only |

Uninstall with `./scripts/uninstall.sh`. Hidden windows are put back on screen first, and your config is kept.

## Keys at a glance

| Keys | Action |
|---|---|
| `⌥h/j/k/l` | Focus left / down / up / right |
| `⌥⇧h/j/k/l` | Move window |
| `⌥1–9`, `⌥a–z` | Go to workspace |
| `⌥⇧1–9`, `⌥⇧a–z` | Send window to workspace |
| `⌥Tab` | Previous workspace |
| `⌥F` / `⌥⇧F` | Fill display / float toggle |
| `⌥[` / `⌥]` | Focus display left / right |
| `⌥⇧[` / `⌥⇧]` | Send window to display left / right |
| `⌥⇧Tab` | Move workspace to next display |
| `⌥/` / `⌥,` | Tiles / accordion layout |
| `⌥-` / `⌥=` | Shrink / grow |
| `⌥⇧;` | Service mode |

Full reference: [docs/keybindings.md](docs/keybindings.md).

## Usage guide

### Workspaces

Every display shows one workspace. `⌥C` shows workspace C (if another display already shows it, focus jumps there). `⌥⇧C` sends the focused window to C without following it. `⌥Tab` flips between the last two workspaces.

### Focus and wrapping

`⌥h/j/k/l` moves focus to the neighboring window. At the edge of a display it crosses to the next display. Past the last display it wraps to the window at the opposite edge, so `⌥l` keeps cycling. Wrapping stays within a row of displays: with the laptop *below* the main monitor, `⌥l` never drops down to it (use `⌥j` or `⌥]`). Turn wrapping off with `focus-wrap = false` or in Settings.

### Fullscreen inside a workspace (`⌥F`)

`⌥F` makes the focused window fill its display. It is rishabhwm's fullscreen, not the green button: you stay on the home desktop.

```
 3 windows, A fullscreen        ⌥l: B on top              ⌥h: back to A
┌──────────────────────┐     ┌──────────┬───────────┐     ┌──────────────────────┐
│                      │     │          │           │     │                      │
│          A           │     │    B     │  (A)      │     │          A           │
│                      │     │          │           │     │                      │
└──────────────────────┘     └──────────┴───────────┘     └──────────────────────┘
 B and C tile underneath      nothing retiles              A still fullscreen
```

- The fullscreen window steps out of the tiling. The others share the display behind it, so "one fullscreen, two tiled" just works.
- `⌥hjkl` cycles focus through all of the workspace's windows. The focused window comes to the front; going back to the fullscreen one brings it back over everything.
- One fullscreen window per workspace. `⌥F` on another window moves fullscreen to it; `⌥F` on the fullscreen window puts it back in its old slot.
- Sending it to another display (`⌥⇧[` / `⌥⇧]`) keeps it fullscreen there.

### Multiple displays

| Keys | Action |
|---|---|
| `⌥[` / `⌥]` | Focus the display to the left / right. Wraps around; with stacked displays it just steps to the other one. |
| `⌥⇧[` / `⌥⇧]` | Send the focused window to the display on the left / right. Focus follows it. Floating windows keep their relative spot, `⌥F` windows stay fullscreen. |
| `⌥⇧h/j/k/l` | Move a window; at the edge of a display it moves onto the next display. |
| `⌥⇧Tab` | Move the whole workspace to the next display. |

The **main display** (the one with the menu bar, set in System Settings → Displays) starts on workspace `1`, even if it's to the right of the laptop. Displays of different sizes and offsets are fine: hidden windows are parked just off an edge where they can't spill onto the other display.

**Pin workspaces** to a display so they always open there:

```toml
[monitors]
"C" = "builtin"   # Claude on the laptop screen
"B" = "main"      # browser on the big monitor
```

Roles: `main`, `secondary` (not main), `builtin` (laptop screen), `external` (not the laptop). If no such display is connected, the workspace opens on the focused display as usual.

### Settings window

Menu bar item → **Settings…** (`⌘,`):

- **Layout**: inner gap, outer gap, accordion padding, focus wrapping.
- **Apps**: per-app workspace and float rules. **Add running app** picks from what's open, or type a bundle id.
- **Pinned workspaces**: workspace → display.

**Save** writes `~/.config/rishabhwm/config.toml` and applies it right away. The file is rewritten, so hand-written comments in it are dropped. You can still edit the file directly (**Open config.toml**) and reload with menu bar → **Reload Config** or `⌥⇧;` then `Esc`.

### Config file

```toml
[apps]                        # app always opens on a workspace
"com.anthropic.claudefordesktop" = "C"
"com.google.Chrome" = "B"

[floating]                    # app floats instead of tiling
"com.docker.docker" = true

[layout]
inner-gap = 0
outer-gap = 0
accordion-padding = 30

[behavior]
focus-wrap = true

[monitors]                    # workspace pinned to a display
"C" = "builtin"
```

Find an app's bundle id with `osascript -e 'id of app "Claude"'`. Details: [docs/configuration.md](docs/configuration.md).

## Docs

- [Keybindings](docs/keybindings.md): every key, service mode, what works from fullscreen.
- [Configuration](docs/configuration.md): app routing, floating apps, gaps, wrapping, pinned workspaces.
- [How it works](docs/architecture.md): design, fullscreen handling, code map.
- [Troubleshooting](docs/troubleshooting.md): permissions, lost windows, logs.
- [Development](docs/development.md): building, testing, debugging.

## Status

Early (v0.1). The core layout and workspace logic is unit tested. The macOS integration is new, so expect rough edges and please [open an issue](https://github.com/rishabh-tole/rishabh-tools/issues).

Known limits:
- Only Desktop 1 of each display is managed.
- Mouse-resizing tiled windows snaps back instead of adjusting the split.
- Keys are fixed for now; app routing, floating, gaps, wrapping and display pins are configurable.
- With an `⌥F` window up, `⌥-` / `⌥=` resize steps are measured against the full tiling, so they can be a little off.

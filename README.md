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
- **Multi-monitor**: each display shows its own workspace. Focus and move cross displays.
- **Lightweight**:
  - ~540 KB native Swift binary with no dependencies.
  - No polling: everything is event driven.
  - No Input Monitoring permission and no SIP changes.
- **Always on**: a LaunchAgent starts it at login and restarts it if it crashes.

## Install

Requires macOS 14+ and the Swift toolchain (Xcode or Command Line Tools: `xcode-select --install`).

```bash
git clone https://github.com/rishabh-tole/rishabhwm.git
cd rishabhwm
./scripts/install.sh
```

Then allow **rishabhwm** under System Settings → Privacy & Security → **Accessibility**. Until you do, the menu bar item shows `⚠︎ wm`. Once allowed, it shows your current workspace (e.g. `C`, or `C · 2` with two displays).

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
| `⌥/` / `⌥,` | Tiles / accordion layout |
| `⌥-` / `⌥=` | Shrink / grow |
| `⌥⇧;` | Service mode |

Full reference: [docs/keybindings.md](docs/keybindings.md).

## Docs

- [Keybindings](docs/keybindings.md): every key, service mode, what works from fullscreen.
- [Configuration](docs/configuration.md): app routing, floating apps, gaps.
- [How it works](docs/architecture.md): design, fullscreen handling, code map.
- [Troubleshooting](docs/troubleshooting.md): permissions, lost windows, logs.
- [Development](docs/development.md): building, testing, debugging.

## Status

Early (v0.1). The core layout and workspace logic is unit tested. The macOS integration is new, so expect rough edges and please [open an issue](https://github.com/rishabh-tole/rishabhwm/issues).

Known limits:
- Only Desktop 1 of each display is managed.
- Mouse-resizing tiled windows snaps back instead of adjusting the split.
- Keys are fixed for now; only app routing, floating and gaps are configurable.

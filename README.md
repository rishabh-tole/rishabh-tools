# rishabh-tools

Small, native macOS utilities. Each one is a self-contained Swift package with no dependencies and runs as a menu bar app started by a LaunchAgent.

| Tool | What it does |
|---|---|
| [rishabhwm](rishabhwm/) | Tiling window manager in the style of AeroSpace that leaves native fullscreen apps and Space swipes alone. |
| [rishabhfc](rishabhfc/) | Drag-and-tap file converter in the style of Tangerine: drag a file, tap Shift, drop on a format. |

## Install

Requires macOS 14+ and the Swift toolchain (`xcode-select --install`). Install whichever tools you want:

```bash
git clone https://github.com/rishabh-tole/rishabh-tools.git
cd rishabh-tools
./rishabhwm/scripts/install.sh
./rishabhfc/scripts/install.sh
```

Both are signed with one self-signed local certificate, `rishabhwm local signing`. It is created in your login keychain on the first build, and it lets macOS permissions survive rebuilds.

To update, run `git pull`, then rerun the install script for each tool. Each tool's README has its usage, configuration and uninstall steps.

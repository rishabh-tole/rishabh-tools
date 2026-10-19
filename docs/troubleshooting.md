# Troubleshooting

## The menu bar shows `⚠︎ wm`

rishabhwm doesn't have Accessibility permission. Open System Settings → Privacy & Security → Accessibility and turn on **rishabhwm**. If it's missing, click **+** and add `~/Applications/rishabhwm.app`. rishabhwm checks every 2 seconds and starts by itself once allowed.

## It stopped working after I reinstalled

Builds are signed with a local self-signed certificate (`rishabhwm local signing` in your login keychain, created by `scripts/signing-identity.sh` on first build), so the permission survives rebuilds. If the certificate is ever deleted or recreated, the signature changes: `install.sh` notices, clears the stale entry, and macOS asks for permission again once. If it still shows as on but nothing works, remove rishabhwm from the Accessibility list and add it back.

## A window disappeared

It's probably on another workspace, parked in the bottom corner of the screen. Try:
- `⌘Tab` to the app: rishabhwm switches to that window's workspace.
- Quit rishabhwm from the menu bar: every parked window comes back on screen.

## A hotkey does nothing

- If a native fullscreen app is in front, only workspace keys and `⌥Tab` work. This is by design.
- Another app may already own that shortcut. Check the log for `hotkey ... taken by another app`.
- Make sure you're on Desktop 1. Other desktops are not managed.

## A window won't tile

- Dialogs, sheets, panels, minimized windows and native fullscreen windows are never tiled.
- Check whether the app is under `[floating]` in the config.
- Windows with a minimum size can't shrink below it, so they may overlap their neighbors.

## Two displays act strangely

Make sure **Displays have separate Spaces** is on (System Settings → Desktop & Dock), then log out and back in.

## Logs

```bash
tail -f ~/Library/Logs/rishabhwm.log
```

For verbose logs, stop the installed copy and run a debug build in a terminal:

```bash
launchctl bootout gui/$(id -u)/com.rishabh.rishabhwm
swift build && RISHABHWM_DEBUG=1 .build/debug/rishabhwm
```

The terminal app running the debug build then needs Accessibility permission. When you're done, start the installed copy again:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.rishabh.rishabhwm.plist
```

## Start, stop, restart

```bash
launchctl kickstart -k gui/$(id -u)/com.rishabh.rishabhwm   # restart
launchctl bootout gui/$(id -u)/com.rishabh.rishabhwm        # stop until next login
```

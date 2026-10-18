#!/usr/bin/env bash
# Stops rishabhwm (it restores hidden windows on exit) and removes the app and LaunchAgent.
# The config at ~/.config/rishabhwm is left in place.
set -euo pipefail
LABEL=com.rishabh.rishabhwm
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/rishabhwm.app"
echo "uninstalled rishabhwm"

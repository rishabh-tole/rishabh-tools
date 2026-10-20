#!/usr/bin/env bash
# Stops rishabhfc and removes the app and LaunchAgent.
set -euo pipefail
LABEL=com.rishabh.rishabhfc
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/rishabhfc.app"
echo "uninstalled rishabhfc"

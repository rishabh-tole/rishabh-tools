#!/usr/bin/env bash
# Installs ~/Applications/rishabhwm.app and a LaunchAgent that starts it at login
# and restarts it if it ever crashes (quitting from the menu bar keeps it off until next login).
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=com.rishabh.rishabhwm
APP_DIR="$HOME/Applications"
APP="$APP_DIR/rishabhwm.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/rishabhwm.log"

./scripts/build-app.sh

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
mkdir -p "$APP_DIR" "$(dirname "$AGENT")"
rm -rf "$APP"
cp -R build/rishabhwm.app "$APP"

cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP/Contents/MacOS/rishabhwm</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
    <key>StandardOutPath</key>
    <string>$LOG</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$AGENT"
echo "installed $APP and started it (log: $LOG)"
echo "first run: allow rishabhwm in System Settings → Privacy & Security → Accessibility"

#!/usr/bin/env bash
# Installs ~/Applications/rishabhfc.app and a LaunchAgent that starts it at login
# and restarts it if it ever crashes (quitting from the menu bar keeps it off until next login).
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=com.rishabh.rishabhfc
DOMAIN="gui/$(id -u)"
APP_DIR="$HOME/Applications"
APP="$APP_DIR/rishabhfc.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/rishabhfc.log"

./scripts/build-app.sh

# bootout returns before the job is gone; bootstrapping too early fails with "Input/output error".
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
for _ in $(seq 50); do
    launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1 || break
    sleep 0.1
done

mkdir -p "$APP_DIR" "$(dirname "$AGENT")"
rm -rf "$APP"
cp -R build/rishabhfc.app "$APP"

cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP/Contents/MacOS/rishabhfc</string>
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

for attempt in 1 2 3 4 5; do
    launchctl bootstrap "$DOMAIN" "$AGENT" 2>/dev/null && break
    [ "$attempt" = 5 ] && { echo "launchctl bootstrap failed; try: launchctl bootstrap $DOMAIN $AGENT" >&2; exit 1; }
    sleep 0.5
done
echo "installed $APP and started it (log: $LOG)"
echo "drag a file and tap Shift. macOS may ask once to let rishabhfc save into Desktop/Documents/Downloads."

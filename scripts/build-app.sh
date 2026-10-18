#!/usr/bin/env bash
# Builds build/rishabhwm.app (release, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/rishabhwm.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/rishabhwm "$APP/Contents/MacOS/rishabhwm"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier com.rishabh.rishabhwm "$APP"
echo "built $APP"

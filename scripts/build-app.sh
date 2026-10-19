#!/usr/bin/env bash
# Builds build/rishabhwm.app (release), signed with a stable local identity so the
# Accessibility permission survives rebuilds (see signing-identity.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/rishabhwm.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/rishabhwm "$APP/Contents/MacOS/rishabhwm"
cp Resources/Info.plist "$APP/Contents/Info.plist"
IDENTITY=$(./scripts/signing-identity.sh)
codesign --force --sign "$IDENTITY" --identifier com.rishabh.rishabhwm "$APP"
echo "built $APP"

#!/usr/bin/env bash
# Builds build/rishabhfc.app (release), signed with the same stable local identity as rishabhwm so
# macOS folder-access grants (Desktop, Documents, Downloads) survive rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/rishabhfc.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/rishabhfc "$APP/Contents/MacOS/rishabhfc"
cp Resources/Info.plist "$APP/Contents/Info.plist"
IDENTITY=$(./scripts/signing-identity.sh)
codesign --force --sign "$IDENTITY" --identifier com.rishabh.rishabhfc "$APP"
echo "built $APP"

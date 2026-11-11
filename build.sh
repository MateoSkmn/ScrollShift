#!/bin/bash
# Baut build/ScrollShift.app
# Mit eigenem Zertifikat: SIGN_IDENTITY="ScrollShift Dev" ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="build/ScrollShift.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/ScrollShift" "$APP/Contents/MacOS/ScrollShift"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# "-" = Ad-hoc-Signatur. Ein eigenes Zertifikat hält die Berechtigung über Neubauten hinweg.
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Fertig: $APP"

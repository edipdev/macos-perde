#!/bin/bash
# Builds Perde and packages it into a launchable .app bundle.
set -eo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="Perde"
APP_DIR="build/${APP_NAME}.app"

echo "> Building ($CONFIG)..."
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/${APP_NAME}"
if [ ! -f "$BIN_PATH" ]; then
    echo "x Binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "> Packaging $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
if [ -f Resources/Perde.icns ]; then
    cp Resources/Perde.icns "$APP_DIR/Contents/Resources/Perde.icns"
fi

# Ad-hoc sign so TCC (Automation) and login-item registration bind to a stable
# identity across rebuilds.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || \
    echo "! codesign skipped (ad-hoc signing unavailable)"

echo "OK: built $APP_DIR"
echo "   Run with: open \"$APP_DIR\""

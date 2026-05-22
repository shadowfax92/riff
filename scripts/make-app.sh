#!/usr/bin/env bash
# Build Riff and assemble it into a proper macOS .app bundle.
#
# A SwiftPM executableTarget produces a bare Mach-O binary. macOS treats it as
# a background process — windows don't activate, no Dock icon, no Cmd-Tab.
# Wrapping the binary in a Contents/{MacOS,Info.plist} layout gives AppKit a
# real bundle so the app behaves like any other GUI app.

set -euo pipefail

CONFIG="${CONFIG:-release}"
APP_NAME="Riff"
BUNDLE_ID="com.riff.Riff"
BUNDLE_VERSION="1"
SHORT_VERSION="0.1.0"
MIN_MACOS="15.0"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/$APP_NAME.app"
BIN_PATH="$PROJECT_DIR/.build/$CONFIG/$APP_NAME"

cd "$PROJECT_DIR"

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Expected binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "→ assembling $APP_NAME.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUNDLE_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper lets you double-click it locally without quarantine warnings.
codesign --force --sign - "$APP_PATH" >/dev/null

echo "✓ $APP_PATH"
echo "  open $APP_PATH"

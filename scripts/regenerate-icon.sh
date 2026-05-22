#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from scripts/make-icon.swift.
#
# Pipeline:
#   1. Run the Swift renderer to produce a 1024×1024 master PNG.
#   2. Use `sips` to downsample into an Apple iconset directory with the
#      required naming (icon_16x16.png, icon_16x16@2x.png, ...).
#   3. Use `iconutil` to package the iconset into AppIcon.icns.
#
# After running, also restart the Dock so it picks up the new icon
# (macOS caches Dock icons aggressively by bundle id).

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

ICONSET="Resources/AppIcon.iconset"
SRC="Resources/AppIcon.png"
ICNS="Resources/AppIcon.icns"

echo "→ rendering 1024×1024 master PNG"
swift scripts/make-icon.swift

echo "→ assembling iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

SPECS=(
  "16   icon_16x16"
  "32   icon_16x16@2x"
  "32   icon_32x32"
  "64   icon_32x32@2x"
  "128  icon_128x128"
  "256  icon_128x128@2x"
  "256  icon_256x256"
  "512  icon_256x256@2x"
  "512  icon_512x512"
  "1024 icon_512x512@2x"
)

for spec in "${SPECS[@]}"; do
  size="${spec%% *}"
  name="${spec##* }"
  sips -z "$size" "$size" "$SRC" --out "$ICONSET/$name.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"
echo "✓ $ICNS"

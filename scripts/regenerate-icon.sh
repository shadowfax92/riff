#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from Resources/AppIcon-source.png.
#
# Pipeline:
#   1. Trim black letterbox + mask rounded corners + resize → Resources/AppIcon.png (1024×1024).
#   2. Downsample via `sips` into the standard Apple iconset directory.
#   3. Pack the iconset into Resources/AppIcon.icns via `iconutil`.
#
# Requires ImageMagick (`brew install imagemagick`) for the masking step.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SOURCE="Resources/AppIcon-source.png"
MASTER="Resources/AppIcon.png"
ICONSET="Resources/AppIcon.iconset"
ICNS="Resources/AppIcon.icns"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing $SOURCE — drop a square master in there before running." >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick (magick) not found. Install with: brew install imagemagick" >&2
  exit 1
fi

echo "→ producing $MASTER from $SOURCE"
# Layout follows Apple's Big Sur icon template: design lives in the inner
# 824×824 area of a 1024×1024 canvas (100px transparent margin all around),
# clipped to a 185px-radius squircle. Without that margin the icon looks
# oversized in the Dock and gets visually "cut" against neighboring apps.
TRIMMED="$(mktemp -t riff-icon-trim).png"
MASKED="$(mktemp -t riff-icon-mask).png"
trap 'rm -f "$TRIMMED" "$MASKED"' EXIT

# 1. Trim the source's outer letterbox and downscale to the design area.
magick "$SOURCE" \
  -fuzz 6% -trim +repage \
  -resize 824x824^ -gravity center -extent 824x824 \
  "$TRIMMED"

# 2. Apply the squircle alpha mask at the standard Big Sur radius.
magick "$TRIMMED" \
  \( -size 824x824 xc:black -fill white \
     -draw "roundrectangle 0,0 823,823 185,185" \) \
  -alpha off -compose CopyOpacity -composite \
  "$MASKED"

# 3. Center the masked design in a 1024×1024 transparent canvas.
magick "$MASKED" \
  -gravity center -background none -extent 1024x1024 \
  "$MASTER"

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
  sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$name.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"
echo "✓ $ICNS"

#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
if [[ "${1:-}" != "--skip-build" ]]; then
  swift build -c release
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' scripts/Info.plist)
APP_DIR="$PROJECT_DIR/dist/$VERSION/AxonTube.app"
HELPER="$PROJECT_DIR/vendor/yt-dlp/yt-dlp"
if [[ ! -x "$HELPER" ]]; then
  printf 'Missing subtitle helper. Run: bash scripts/prepare-ytdlp.sh\n' >&2
  exit 1
fi
printf '%s  %s\n' 'b82c3626952e6c14eaf654cc565866775ffd0b9ffb7021628ac59b42c2f4f244' "$HELPER" | shasum -a 256 --check
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Helpers" "$APP_DIR/Contents/Resources/Samples" "$APP_DIR/Contents/Resources/Licenses/yt-dlp/sources/build-metadata"
cp .build/release/AxonTube "$APP_DIR/Contents/MacOS/AxonTube"
cp "$HELPER" "$APP_DIR/Contents/Helpers/yt-dlp"
chmod 755 "$APP_DIR/Contents/Helpers/yt-dlp"
cp vendor/yt-dlp/LICENSE vendor/yt-dlp/THIRD_PARTY_LICENSES.txt vendor/yt-dlp/PROVENANCE.md "$APP_DIR/Contents/Resources/Licenses/yt-dlp/"
cp vendor/yt-dlp/sources/build-metadata/pyproject.toml "$APP_DIR/Contents/Resources/Licenses/yt-dlp/sources/build-metadata/"
cp NOTICE.md "$APP_DIR/Contents/Resources/Licenses/NOTICE.md"
cp docs/SOURCE-ACCESS.md "$APP_DIR/Contents/Resources/Licenses/"
cp README.md "$APP_DIR/Contents/Resources/README.md"
cp README.zh-CN.md "$APP_DIR/Contents/Resources/README.zh-CN.md"
cp LICENSE "$APP_DIR/Contents/Resources/Licenses/LICENSE"
cp Samples/* "$APP_DIR/Contents/Resources/Samples/"
cp scripts/Info.plist "$APP_DIR/Contents/Info.plist"
if [[ -f "dist/PlayerIcon.icns" ]]; then
  cp dist/PlayerIcon.icns "$APP_DIR/Contents/Resources/PlayerIcon.icns"
fi
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"

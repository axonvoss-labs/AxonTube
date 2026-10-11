#!/bin/bash
# Explicit dependency download; packaging itself never connects to the network.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$PROJECT_DIR/vendor/yt-dlp"
mkdir -p "$VENDOR_DIR"
EXPECTED="b82c3626952e6c14eaf654cc565866775ffd0b9ffb7021628ac59b42c2f4f244"
if [[ ! -f "$VENDOR_DIR/yt-dlp" ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 \
    'https://github.com/yt-dlp/yt-dlp/releases/download/2026.06.09/yt-dlp_macos' \
    --output "$VENDOR_DIR/yt-dlp.download"
  printf '%s  %s\n' "$EXPECTED" "$VENDOR_DIR/yt-dlp.download" | shasum -a 256 --check
  mv "$VENDOR_DIR/yt-dlp.download" "$VENDOR_DIR/yt-dlp"
fi
printf '%s  %s\n' "$EXPECTED" "$VENDOR_DIR/yt-dlp" | shasum -a 256 --check
chmod 755 "$VENDOR_DIR/yt-dlp"

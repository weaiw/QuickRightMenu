#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/QuickRightMenu-check.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
CHECK_BINARY="$CHECK_DIR/check"
if [ "${1:-}" = "--ui" ]; then
  PREVIEW_APP="$CHECK_DIR/QuickRightMenu Preview.app"
  mkdir -p "$PREVIEW_APP/Contents/MacOS"
  CHECK_BINARY="$PREVIEW_APP/Contents/MacOS/check"
  cat > "$PREVIEW_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.liaowenbin.QuickRightMenu.Preview</string><key>CFBundleName</key><string>QuickRightMenu Preview</string><key>CFBundleExecutable</key><string>check</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
  echo "$PREVIEW_APP"
fi
clang -fobjc-arc -fmodules -target arm64-apple-macos13.0 \
  -framework Cocoa -framework FinderSync -framework ImageIO -framework UniformTypeIdentifiers \
  -framework PDFKit -framework Vision -framework CoreText \
  "$ROOT/Tests/check.m" "$ROOT/Sources/App/QRFileOperations.m" -o "$CHECK_BINARY"
"$CHECK_BINARY" "$@"

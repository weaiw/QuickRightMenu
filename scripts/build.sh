#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/QuickRightMenu.app"
EXT="$APP/Contents/PlugIns/QuickRightMenu Extension.appex"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
MODULE_CACHE="$BUILD/ModuleCache"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns"
mkdir -p "$EXT/Contents/MacOS" "$EXT/Contents/Resources"
mkdir -p "$MODULE_CACHE"

if [ ! -f "$ROOT/Resources/AppIcon.icns" ] && command -v python3 >/dev/null 2>&1; then
  python3 "$ROOT/scripts/make_icon.py" || true
fi

cp "$ROOT/Resources/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/ExtensionInfo.plist" "$EXT/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

clang \
  -isysroot "$SDK" \
  -target arm64-apple-macos13.0 \
  -fmodules \
  -fmodules-cache-path="$MODULE_CACHE" \
  -fobjc-arc \
  -framework Cocoa \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  -framework PDFKit \
  -framework Vision \
  -framework CoreText \
  "$ROOT/Sources/App/main.m" \
  "$ROOT/Sources/App/QRFileOperations.m" \
  -o "$APP/Contents/MacOS/QuickRightMenu"

clang \
  -isysroot "$SDK" \
  -target arm64-apple-macos13.0 \
  -fmodules \
  -fmodules-cache-path="$MODULE_CACHE" \
  -fobjc-arc \
  -framework Cocoa \
  -framework FinderSync \
  -framework UniformTypeIdentifiers \
  -framework Foundation \
  "$ROOT/Sources/FinderExtension/main.m" \
  "$ROOT/Sources/FinderExtension/FinderSync.m" \
  -o "$EXT/Contents/MacOS/QuickRightMenu Extension"

/usr/libexec/PlistBuddy -c "Set :NSExtension:NSExtensionPrincipalClass FinderSync" "$EXT/Contents/Info.plist"

codesign --force --sign - --entitlements "$ROOT/Resources/Extension.entitlements" "$EXT"
codesign --force --sign - --entitlements "$ROOT/Resources/App.entitlements" "$APP"

echo "$APP"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DOAC Border"
BUNDLE_ID="com.doac.borderapp"

# Build each arch separately and lipo them into a universal binary. (A single
# `swift build --arch arm64 --arch x86_64` invocation would be simpler, but it
# routes through SwiftPM's xcbuild-based multi-arch build system, which emits
# Make-style .d dependency files that mis-parse any colon in the checkout
# path -- broken on machines whose path contains one, as this one does.)
swift build -c release --arch arm64
swift build -c release --arch x86_64

APP_DIR="$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

lipo -create \
    ".build/arm64-apple-macosx/release/DOACBorderApp" \
    ".build/x86_64-apple-macosx/release/DOACBorderApp" \
    -output "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "Resources/Template border V1.svg" "$APP_DIR/Contents/Resources/"
cp "Resources/Template border V2.svg" "$APP_DIR/Contents/Resources/"

cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP_DIR"
echo "Built $APP_DIR"

rm -f "$APP_NAME.zip"
zip -r -q "$APP_NAME.zip" "$APP_DIR"
echo "Zipped $APP_NAME.zip"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DOAC Border"
BUNDLE_ID="com.doac.borderapp"

swift build -c release

APP_DIR="$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp ".build/release/DOACBorderApp" "$APP_DIR/Contents/MacOS/$APP_NAME"
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

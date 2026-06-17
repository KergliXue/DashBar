#!/bin/bash
set -e

# Build DashBar release binary and package as .app
# Usage: ./scripts/package.sh [--install]

echo "=== Building DashBar in release mode ==="
cd "$(dirname "$0")/.."
swift build -c release

APP_DIR="$(pwd)/.build/DashBar.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp .build/release/DashBar "$APP_DIR/Contents/MacOS/DashBar"

# Copy icons
if [ -f "Sources/DashBar/Resources/AppIcon.icns" ]; then
    cp Sources/DashBar/Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
if [ -f "Sources/DashBar/Resources/AppIcon-dark.icns" ]; then
    cp Sources/DashBar/Resources/AppIcon-dark.icns "$APP_DIR/Contents/Resources/AppIcon-dark.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DashBar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.dashbar.app</string>
    <key>CFBundleName</key>
    <string>DashBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "DashBar.app created at $APP_DIR"

if [ "$1" = "--install" ]; then
    killall DashBar 2>/dev/null || true
    sleep 1
    INSTALL="/Applications/DashBar.app"
    rm -rf "$INSTALL"
    cp -R "$APP_DIR" "$INSTALL"
    echo "Installed to $INSTALL"
    open "$INSTALL"
fi

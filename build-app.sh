#!/bin/bash

# Build script for Claude Pings macOS app

set -e

APP_NAME="Claude Pings"
BUNDLE_ID="com.claudecode.pings"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building Claude Pings..."

# Build the executable
cd ClaudeIndicator
swift build -c release

# Create app bundle structure
cd ..
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "ClaudeIndicator/.build/release/ClaudeIndicator" "$APP_BUNDLE/Contents/MacOS/"

# Copy icon if exists
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeIndicator</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudecode.pings</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Claude Pings</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Pings</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Claude Pings needs to control Terminal to switch to the correct tab when you click a ping.</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo ""
echo "Build complete!"
echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To run:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "Don't forget to configure Claude Code hooks in ~/.claude/settings.json"

#!/bin/bash

# Set variables
APP_NAME="CleanYourMac"
BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Build the app in release mode
swift build -c release

# Create app bundle structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy the executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>feafea
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>NSFileManagerUsageDescription</key>
    <string>CleanYourMac needs access to your files to scan and manage them.</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy resource files
cp -R Sources/CleanYourMac/Resources/* "$RESOURCES/" 2>/dev/null || :

echo "App bundle created at $APP_BUNDLE"
echo "You can now run it by opening the app bundle or using 'open $APP_BUNDLE'" 
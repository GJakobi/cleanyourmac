#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Set variables
APP_NAME="CleanYourMac"

echo "--- Building application ---"
# Build the app in release mode
swift build -c release

# Get the correct build directory from Swift Package Manager
BUILD_DIR=$(swift build -c release --show-bin-path)
echo "Build directory is: $BUILD_DIR"
echo "--- Listing contents of build directory ---"
ls -l "$BUILD_DIR"

DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Create app bundle structure
echo "--- Creating .app bundle structure ---"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Check if the executable exists
EXECUTABLE_PATH="$BUILD_DIR/$APP_NAME"
if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "ERROR: Executable not found at $EXECUTABLE_PATH"
    exit 1
fi

# Copy the executable
echo "--- Copying executable to .app bundle ---"
cp "$EXECUTABLE_PATH" "$MACOS/"
echo "--- Listing contents of MacOS directory in .app bundle ---"
ls -l "$MACOS"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.gjakobi.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
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
echo "--- Copying resources ---"
cp -R Sources/CleanYourMac/Resources/* "$RESOURCES/" 2>/dev/null || :

echo "--- .app bundle created successfully ---"
echo "Location: $APP_BUNDLE"

echo "You can now run it by opening the app bundle or using 'open $APP_BUNDLE'" 
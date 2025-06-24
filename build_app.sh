#!/bin/bash

# A robust script to build a macOS .app bundle from a Swift Package.
# This script will exit immediately if any command fails.
set -eo pipefail

# --- Configuration ---
readonly APP_NAME="CleanYourMac"
readonly DIST_DIR="dist"
readonly APP_BUNDLE_PATH="$DIST_DIR/$APP_NAME.app"

# --- Helper Functions ---
log() {
    echo "▶ $1"
}

# --- Main Build Logic ---
main() {
    log "Starting build process for $APP_NAME..."

    # 1. Clean up previous build artifacts
    log "Cleaning up old build artifacts in '$DIST_DIR'..."
    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"

    # 2. Build the Swift package in release mode
    log "Building Swift package in release configuration..."
    swift build -c release

    # 3. Determine the architecture-specific build directory
    local build_dir
    build_dir=$(swift build -c release --show-bin-path)
    log "Build directory determined as: $build_dir"

    # 4. Create the .app bundle structure
    log "Creating .app bundle structure at '$APP_BUNDLE_PATH'..."
    local macos_dir="$APP_BUNDLE_PATH/Contents/MacOS"
    local resources_dir="$APP_BUNDLE_PATH/Contents/Resources"
    mkdir -p "$macos_dir"
    mkdir -p "$resources_dir"

    # 5. Copy the executable
    log "Copying executable..."
    local executable_path="$build_dir/$APP_NAME"
    if [[ ! -f "$executable_path" ]]; then
        log "ERROR: Executable not found at '$executable_path'"
        exit 1
    fi
    cp "$executable_path" "$macos_dir/"
    log "Executable copied to '$macos_dir'"

    # 6. Create Info.plist with automatic versioning
    # It will use the latest git tag (like v1.2.3) as the version.
    local version
    version=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
    log "Using version '$version' for Info.plist"

    log "Creating Info.plist..."
    cat > "$APP_BUNDLE_PATH/Contents/Info.plist" << EOF
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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

    # 7. Copy resource files (if any exist)
    log "Copying resources..."
    local app_resources_dir="Sources/$APP_NAME/Resources"
    if [[ -d "$app_resources_dir" ]] && [[ -n "$(ls -A "$app_resources_dir")" ]]; then
        cp -R "$app_resources_dir"/* "$resources_dir/"
    else
        log "No resources found to copy."
    fi

    log "✅ Build successful!"
    log "App bundle located at: $APP_BUNDLE_PATH"
}

# --- Run main function ---
main 
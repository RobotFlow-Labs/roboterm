#!/bin/bash
# ROBOTERM build script
# Usage: ./scripts/build.sh [--install] [--run] [--release]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Parse arguments
DO_INSTALL=false
DO_RUN=false
CONFIG="Debug"
for arg in "$@"; do
    case "$arg" in
        --install)  DO_INSTALL=true ;;
        --run)      DO_RUN=true ;;
        --release)  CONFIG="Release" ;;
    esac
done

echo "=== ROBOTERM Build ($CONFIG) ==="

# Generate Xcode project
echo "[1/3] Generating Xcode project..."
xcodegen generate 2>&1 | tail -1

# Build
echo "[2/3] Building..."
xcodebuild -project roboterm.xcodeproj -scheme roboterm -configuration "$CONFIG" build 2>&1 | tail -3

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/roboterm-*/Build/Products/"$CONFIG"/ROBOTERM.app -maxdepth 0 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "ERROR: Build output not found"
    exit 1
fi

echo "Built: $APP_PATH"

# Copy resources that xcodegen doesn't handle
RESOURCES_DIR="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES_DIR"
cp -f "$PROJECT_DIR/scripts/roboterm-tools.sh" "$RESOURCES_DIR/" 2>/dev/null || true
cp -f "$PROJECT_DIR/Resources/Roboterm.sdef" "$RESOURCES_DIR/" 2>/dev/null || true
cp -f "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/" 2>/dev/null || true
cp -rf "$PROJECT_DIR/Resources/AppIcon.appiconset" "$RESOURCES_DIR/" 2>/dev/null || true
echo "Resources copied to bundle"

# Install to /Applications
if $DO_INSTALL; then
    echo "[3/3] Installing to /Applications..."
    # Kill running instance first
    pkill -x ROBOTERM 2>/dev/null && sleep 1 || true
    rm -rf /Applications/ROBOTERM.app
    cp -a "$APP_PATH" /Applications/ROBOTERM.app
    codesign --force --deep --sign - /Applications/ROBOTERM.app 2>/dev/null
    echo "Installed: /Applications/ROBOTERM.app"
    APP_PATH="/Applications/ROBOTERM.app"
fi

# Run
if $DO_RUN; then
    echo "Launching ROBOTERM..."
    open "$APP_PATH"
fi

echo "=== Done ==="

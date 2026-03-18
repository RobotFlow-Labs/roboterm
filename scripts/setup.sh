#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

echo "=== ROBOTERM setup ==="

# 1. Initialize ghostty submodule
if [ ! -f ghostty/build.zig ]; then
    echo "Initializing ghostty submodule..."
    git submodule update --init --recursive ghostty
else
    echo "Ghostty submodule already initialized."
fi

# 2. Build GhosttyKit xcframework
XCFRAMEWORK="$ROOT/ghostty/macos/GhosttyKit.xcframework"
if [ -d "$XCFRAMEWORK" ]; then
    echo "GhosttyKit.xcframework already exists, skipping build."
    echo "  (delete $XCFRAMEWORK and re-run to rebuild)"
else
    echo "Building GhosttyKit.xcframework (this takes a few minutes)..."
    cd ghostty
    zig build -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast
    cd "$ROOT"
    echo "GhosttyKit.xcframework built successfully."
fi

# 3. Generate Xcode project (requires xcodegen)
if command -v xcodegen &>/dev/null; then
    echo "Generating Xcode project..."
    xcodegen generate
    echo "roboterm.xcodeproj generated."
else
    echo ""
    echo "WARNING: xcodegen not found. Install it to generate the Xcode project:"
    echo "  brew install xcodegen"
    echo "  xcodegen generate"
fi

# 4. Install Ghostty config theme
mkdir -p ~/.config/ghostty
if [ ! -f ~/.config/ghostty/config ]; then
    cp Resources/ghostty/config ~/.config/ghostty/config
    echo "Installed Industrial Cyberpunk theme to ~/.config/ghostty/config"
fi

# 5. Create default hosts config
mkdir -p ~/.config/roboterm
if [ ! -f ~/.config/roboterm/hosts.json ]; then
    echo '[{"name":"JETSON","host":"jetson.local","type":"jetson"},{"name":"ANIMA-MOTHER","host":"192.168.1.110","type":"server"}]' > ~/.config/roboterm/hosts.json
    echo "Created default hosts config at ~/.config/roboterm/hosts.json"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "To build and run:"
echo "  ./scripts/build.sh --install --run"
echo ""
echo "Or manually:"
echo "  xcodebuild -project roboterm.xcodeproj -scheme roboterm -configuration Debug build"

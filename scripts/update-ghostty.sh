#!/bin/bash
# Update Ghostty submodule to latest and rebuild GhosttyKit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=== Updating Ghostty ==="

# Pull latest
cd ghostty
BEFORE=$(git rev-parse HEAD)
git fetch origin
git checkout origin/main
AFTER=$(git rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
    echo "Already up to date: $BEFORE"
    exit 0
fi

echo "Updated: $BEFORE → $AFTER"
echo ""

# Check if GhosttyKit needs rebuild
if [ -d "macos/GhosttyKit.xcframework" ]; then
    echo "GhosttyKit.xcframework exists — checking if rebuild needed..."

    # Check if zig is available for rebuilding
    if command -v zig &>/dev/null; then
        echo "Rebuilding GhosttyKit..."
        zig build -Doptimize=ReleaseFast
        echo "Rebuild complete."
    else
        echo "WARNING: zig not installed — using existing xcframework"
        echo "Install zig to rebuild: brew install zig"
    fi
else
    echo "WARNING: GhosttyKit.xcframework not found"
    echo "Build Ghostty first or copy from Ghostty.app"
fi

cd "$PROJECT_DIR"

echo ""
echo "=== Ghostty Update Complete ==="
echo "Now rebuild ROBOTERM: ./scripts/build.sh --install --run"

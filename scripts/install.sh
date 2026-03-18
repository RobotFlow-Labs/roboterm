#!/bin/bash
# ROBOTERM Installer — installs to /Applications
# Usage: curl -fsSL https://raw.githubusercontent.com/RobotFlow-Labs/roboterm/main/scripts/install.sh | bash

set -euo pipefail

VERSION="0.5.1"
ARCH="arm64"
URL="https://github.com/RobotFlow-Labs/roboterm/releases/download/v${VERSION}/ROBOTERM-v${VERSION}-${ARCH}.zip"
INSTALL_DIR="/Applications"
TMP_DIR=$(mktemp -d)

# Colors
O='\033[38;2;255;59;0m'
G='\033[38;2;0;255;136m'
C='\033[38;2;0;221;255m'
B='\033[1m'
R='\033[0m'

echo -e "${O}${B}"
echo "  ____   ___  ____   ___ _____ _____ ____  __  __ "
echo " |  _ \\ / _ \\| __ ) / _ \\_   _| ____|  _ \\|  \\/  |"
echo " | |_) | | | |  _ \\| | | || | |  _| | |_) | |\\/| |"
echo " |  _ <| |_| | |_) | |_| || | | |___|  _ <| |  | |"
echo " |_| \\_\\\\___/|____/ \\___/ |_| |_____|_| \\_\\_|  |_|"
echo -e "${R}"
echo -e "  ${C}Installer v${VERSION}${R}"
echo ""

# Check architecture
if [ "$(uname -m)" != "arm64" ]; then
    echo -e "${O}Error: ROBOTERM requires Apple Silicon (arm64).${R}"
    echo "Your architecture: $(uname -m)"
    exit 1
fi

# Check macOS version
MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if [ "$MACOS_MAJOR" -lt 13 ]; then
    echo -e "${O}Error: ROBOTERM requires macOS 13 (Ventura) or later.${R}"
    echo "Your version: $(sw_vers -productVersion)"
    exit 1
fi

# Download
echo -e "${G}Downloading ROBOTERM v${VERSION}...${R}"
curl -fsSL "$URL" -o "${TMP_DIR}/roboterm.zip"

# Extract
echo -e "${G}Installing to ${INSTALL_DIR}...${R}"
cd "$TMP_DIR"
unzip -q roboterm.zip

# Remove old version if exists
if [ -d "${INSTALL_DIR}/ROBOTERM.app" ]; then
    echo -e "  Removing previous version..."
    rm -rf "${INSTALL_DIR}/ROBOTERM.app"
fi

# Install
mv ROBOTERM.app "${INSTALL_DIR}/"

# Cleanup
rm -rf "$TMP_DIR"

echo ""
echo -e "${G}${B}ROBOTERM installed successfully!${R}"
echo ""
echo -e "  ${C}Launch:${R}  open -a ROBOTERM"
echo -e "  ${C}CLI:${R}    Add to ~/.zshrc:"
echo -e "          source /Applications/ROBOTERM.app/Contents/Resources/roboterm-tools.sh"
echo ""
echo -e "  ${G}Then type ${B}rt${R}${G} for 31 robotics commands.${R}"
echo ""

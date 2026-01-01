#!/bin/bash
set -e

# Install Mozilla Firefox on macOS
# Downloads directly from Mozilla's website

APP_NAME="Mozilla Firefox"
VENDOR_URL="https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-US"
DMG_NAME="Firefox.dmg"
TEMP_DIR=$(mktemp -d)
MOUNT_POINT="/Volumes/Firefox"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    if [ -d "$MOUNT_POINT" ]; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIR"
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo -e "${GREEN}Installing $APP_NAME...${NC}"
echo ""

# Detect OS version
OS_VERSION=$(sw_vers -productVersion)
echo -e "${YELLOW}Detected macOS version: $OS_VERSION${NC}"
echo ""

# Download DMG from Mozilla
echo -e "${YELLOW}Downloading installer from Mozilla...${NC}"
DMG_PATH="$TEMP_DIR/$DMG_NAME"
curl -L "$VENDOR_URL" -o "$DMG_PATH"

if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}Failed to download Firefox installer${NC}"
    exit 1
fi

echo -e "${GREEN}Downloaded installer: $DMG_PATH${NC}"
echo ""

# Mount DMG
echo -e "${YELLOW}Mounting DMG...${NC}"
hdiutil attach "$DMG_PATH" -quiet -nobrowse -mountpoint "$MOUNT_POINT"

if [ ! -d "$MOUNT_POINT" ]; then
    echo -e "${RED}Failed to mount DMG${NC}"
    exit 1
fi

# Find Firefox.app in the mounted volume
FIREFOX_APP=$(find "$MOUNT_POINT" -name "Firefox.app" -maxdepth 2 | head -1)

if [ -z "$FIREFOX_APP" ]; then
    echo -e "${RED}Firefox.app not found in DMG${NC}"
    hdiutil detach "$MOUNT_POINT" -quiet
    exit 1
fi

# Copy Firefox.app to Applications
echo -e "${YELLOW}Installing Firefox to /Applications...${NC}"
if [ -d "/Applications/Firefox.app" ]; then
    echo -e "${YELLOW}Removing existing Firefox installation...${NC}"
    rm -rf "/Applications/Firefox.app"
fi

cp -R "$FIREFOX_APP" "/Applications/"

# Unmount DMG
echo -e "${YELLOW}Unmounting DMG...${NC}"
hdiutil detach "$MOUNT_POINT" -quiet

echo ""
echo -e "${GREEN}$APP_NAME installed successfully!${NC}"
echo -e "${GREEN}Firefox is now available in /Applications${NC}"


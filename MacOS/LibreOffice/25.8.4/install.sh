#!/bin/bash
set -e

# Parse WTF parameter
WTF=false
for arg in "$@"; do
    case $arg in
        -WTF|--WTF)
            WTF=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check for WTF environment variable if parameter not provided
if [ "$WTF" != true ] && [ "$INSTALLRELAY_WTF" = "1" ]; then
    WTF=true
fi

# Install LibreOffice on macOS
# Downloads directly from LibreOffice website

APP_NAME="LibreOffice"
VERSION="25.8.4"

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    DMG_NAME="LibreOffice_25.8.4_MacOS_aarch64.dmg"
    VENDOR_URL="https://www.libreoffice.org/donate/dl/mac-aarch64/25.8.4/en-US/LibreOffice_25.8.4_MacOS_aarch64.dmg"
else
    DMG_NAME="LibreOffice_25.8.4_MacOS_x86-64.dmg"
    VENDOR_URL="https://www.libreoffice.org/donate/dl/mac-x86_64/25.8.4/en-US/LibreOffice_25.8.4_MacOS_x86-64.dmg"
fi

if [ "$WTF" != true ]; then
    TEMP_DIR=$(mktemp -d)
    MOUNT_POINT="/Volumes/LibreOffice"
    
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
else
    TEMP_DIR="/tmp/wtf-test"
    MOUNT_POINT="/Volumes/LibreOffice"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ "$WTF" = true ]; then
    echo -e "${GREEN}[WTF] Would install: $APP_NAME $VERSION${NC}"
else
    echo -e "${GREEN}Installing $APP_NAME $VERSION...${NC}"
fi
echo ""

# Detect OS version
OS_VERSION=$(sw_vers -productVersion)
echo -e "${YELLOW}Detected macOS version: $OS_VERSION${NC}"
echo -e "${YELLOW}Detected architecture: $ARCH${NC}"
echo ""

if [ "$WTF" = true ]; then
    echo -e "${YELLOW}[WTF] Would download installer from LibreOffice...${NC}"
    echo -e "${YELLOW}[WTF] Installer URL: $VENDOR_URL${NC}"
    echo -e "${YELLOW}[WTF] Installer name: $DMG_NAME${NC}"
    
    # Test URL accessibility
    if curl -sL -I "$VENDOR_URL" | head -1 | grep -q "200\|301\|302"; then
        echo -e "${GREEN}[WTF] URL is accessible${NC}"
        CONTENT_LENGTH=$(curl -sL -I "$VENDOR_URL" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
        if [ -n "$CONTENT_LENGTH" ]; then
            echo -e "${YELLOW}[WTF] Content-Length: $CONTENT_LENGTH${NC}"
        fi
    else
        echo -e "${RED}[WTF] URL check failed${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}[WTF] Would mount DMG and copy LibreOffice.app to /Applications/${NC}"
    echo -e "${GREEN}[WTF] Installation test completed - no changes made${NC}"
else
    # Download DMG from LibreOffice
    echo -e "${YELLOW}Downloading installer from LibreOffice...${NC}"
    DMG_PATH="$TEMP_DIR/$DMG_NAME"
    curl -L "$VENDOR_URL" -o "$DMG_PATH"

    if [ ! -f "$DMG_PATH" ]; then
        echo -e "${RED}Failed to download LibreOffice installer${NC}"
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

    # Find LibreOffice.app in the mounted volume
    LIBREOFFICE_APP=$(find "$MOUNT_POINT" -name "LibreOffice.app" -maxdepth 2 | head -1)

    if [ -z "$LIBREOFFICE_APP" ]; then
        echo -e "${RED}LibreOffice.app not found in DMG${NC}"
        hdiutil detach "$MOUNT_POINT" -quiet
        exit 1
    fi

    # Copy LibreOffice.app to Applications
    echo -e "${YELLOW}Installing LibreOffice to /Applications...${NC}"
    if [ -d "/Applications/LibreOffice.app" ]; then
        echo -e "${YELLOW}Removing existing LibreOffice installation...${NC}"
        rm -rf "/Applications/LibreOffice.app"
    fi

    cp -R "$LIBREOFFICE_APP" "/Applications/"

    # Unmount DMG
    echo -e "${YELLOW}Unmounting DMG...${NC}"
    hdiutil detach "$MOUNT_POINT" -quiet

    echo ""
    echo -e "${GREEN}$APP_NAME $VERSION installed successfully!${NC}"
    echo -e "${GREEN}LibreOffice is now available in /Applications${NC}"
fi



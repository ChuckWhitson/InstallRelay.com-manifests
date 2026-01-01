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

# Configuration
# TODO: Update these values for your application
APP_NAME="Application Name"
VERSION="1.0.0"

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
fi

# Detect architecture
ARCH=$(uname -m)
# TODO: Update installer names and URLs based on architecture
if [ "$ARCH" = "arm64" ]; then
    INSTALLER_NAME="app-name-arm64.dmg"
    VENDOR_URL="https://example.com/downloads/app-name-arm64.dmg"
else
    INSTALLER_NAME="app-name-x64.dmg"
    VENDOR_URL="https://example.com/downloads/app-name-x64.dmg"
fi

if [ "$WTF" != true ]; then
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
else
    TEMP_DIR="/tmp/wtf-test"
fi

if [ "$WTF" = true ]; then
    echo "[WTF] Would install: $APP_NAME $VERSION"
else
    echo "Installing $APP_NAME $VERSION..."
fi

if [ "$WTF" = true ]; then
    echo "[WTF] Would download installer from vendor..."
    echo "[WTF] Installer URL: $VENDOR_URL"
    echo "[WTF] Installer name: $INSTALLER_NAME"
    echo "[WTF] Architecture: $ARCH"
    
    # Test URL accessibility
    if curl -sL -I "$VENDOR_URL" | head -1 | grep -q "200\|301\|302"; then
        echo "[WTF] URL is accessible"
        CONTENT_LENGTH=$(curl -sL -I "$VENDOR_URL" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
        if [ -n "$CONTENT_LENGTH" ]; then
            echo "[WTF] Content-Length: $CONTENT_LENGTH"
        fi
    else
        echo "[WTF] URL check failed" >&2
        exit 1
    fi
    
    # TODO: Update installation steps based on your application
    echo "[WTF] Would mount DMG and copy application to /Applications/"
    echo "[WTF] Installation test completed - no changes made"
else
    # Download installer directly from vendor
    INSTALLER_PATH="$TEMP_DIR/$INSTALLER_NAME"
    echo "Downloading installer from vendor..."
    curl -L "$VENDOR_URL" -o "$INSTALLER_PATH"

    if [ ! -f "$INSTALLER_PATH" ]; then
        echo "Error: Failed to download installer"
        exit 1
    fi

    # Mount DMG and install
    # TODO: Update installation steps based on your application type
    echo "Installing..."
    MOUNT_POINT=$(mktemp -d)
    hdiutil attach "$INSTALLER_PATH" -mountpoint "$MOUNT_POINT" -quiet

    # Find and copy the application
    # TODO: Update application name
    if [ -d "$MOUNT_POINT/AppName.app" ]; then
        if [ -d "/Applications/AppName.app" ]; then
            echo "Removing existing installation..."
            rm -rf "/Applications/AppName.app"
        fi
        cp -R "$MOUNT_POINT/AppName.app" /Applications/
    elif [ -d "$MOUNT_POINT"/*.app ]; then
        APP_NAME_FOUND=$(basename "$MOUNT_POINT"/*.app)
        if [ -d "/Applications/$APP_NAME_FOUND" ]; then
            echo "Removing existing installation..."
            rm -rf "/Applications/$APP_NAME_FOUND"
        fi
        cp -R "$MOUNT_POINT"/*.app /Applications/
    else
        echo "Error: Could not find application in DMG"
        exit 1
    fi

    # Unmount
    hdiutil detach "$MOUNT_POINT" -quiet
    rmdir "$MOUNT_POINT"

    echo "Installation completed successfully!"
    echo "$APP_NAME is now available in /Applications"
fi


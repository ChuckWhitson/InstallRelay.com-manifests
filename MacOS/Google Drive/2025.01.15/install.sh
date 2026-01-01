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
APP_NAME="Google Drive"
VERSION="2025.01.15"
VENDOR_URL="https://dl.google.com/drive-file-stream/GoogleDrive.dmg"
INSTALLER_NAME="GoogleDrive.dmg"

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
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
    echo "[WTF] Would download installer from Google..."
    echo "[WTF] Installer URL: $VENDOR_URL"
    echo "[WTF] Installer name: $INSTALLER_NAME"
    
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
    
    echo "[WTF] Would mount DMG and copy application to /Applications/"
    echo "[WTF] Installation test completed - no changes made"
else
    # Download installer directly from Google
    INSTALLER_PATH="$TEMP_DIR/$INSTALLER_NAME"
    echo "Downloading installer from Google..."
    curl -L "$VENDOR_URL" -o "$INSTALLER_PATH"

    # Mount DMG and install
    echo "Installing..."
    MOUNT_POINT=$(mktemp -d)
    hdiutil attach "$INSTALLER_PATH" -mountpoint "$MOUNT_POINT" -quiet

    # Find and copy the application
    if [ -d "$MOUNT_POINT/Google Drive.app" ]; then
        cp -R "$MOUNT_POINT/Google Drive.app" /Applications/
    elif [ -d "$MOUNT_POINT"/*.app ]; then
        cp -R "$MOUNT_POINT"/*.app /Applications/
    else
        echo "Error: Could not find application in DMG"
        exit 1
    fi

    # Unmount
    hdiutil detach "$MOUNT_POINT" -quiet
    rmdir "$MOUNT_POINT"

    echo "Installation completed successfully!"
    echo "Please sign in with your Google account to start syncing."
fi


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
            CONFIG_TEMPLATE="${arg:-default}"  # Optional: "default", "secure", "enterprise"
            shift
            ;;
    esac
done

# Check for WTF environment variable if parameter not provided
if [ "$WTF" != true ] && [ "$INSTALLRELAY_WTF" = "1" ]; then
    WTF=true
fi

# Configuration
APP_NAME="FileZilla"
VERSION="3.67.1"
CONFIG_TEMPLATE="${CONFIG_TEMPLATE:-default}"

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    INSTALLER_NAME="FileZilla_3.67.1_macos-arm64-app.dmg"
    VENDOR_URL="https://download.filezilla-project.org/client/FileZilla_3.67.1_macos-arm64-app.dmg"
else
    INSTALLER_NAME="FileZilla_3.67.1_macos-x86_64-app.dmg"
    VENDOR_URL="https://download.filezilla-project.org/client/FileZilla_3.67.1_macos-x86_64-app.dmg"
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
    echo "[WTF] Would download installer from FileZilla website..."
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
    if [ -n "$CONFIG_TEMPLATE" ]; then
        echo "[WTF] Would apply configuration template: $CONFIG_TEMPLATE"
    fi
    echo "[WTF] Installation test completed - no changes made"
else
    # Download installer directly from FileZilla website
    INSTALLER_PATH="$TEMP_DIR/$INSTALLER_NAME"
    echo "Downloading installer from FileZilla website..."
    curl -L "$VENDOR_URL" -o "$INSTALLER_PATH"

    # Mount DMG and install
    echo "Installing..."
    MOUNT_POINT=$(mktemp -d)
    hdiutil attach "$INSTALLER_PATH" -mountpoint "$MOUNT_POINT" -quiet

    # Copy application
    cp -R "$MOUNT_POINT"/*.app /Applications/

    # Unmount
    hdiutil detach "$MOUNT_POINT" -quiet
    rmdir "$MOUNT_POINT"

    # Apply configuration if specified
    if [ -n "$CONFIG_TEMPLATE" ]; then
        echo "Applying $CONFIG_TEMPLATE configuration..."
        CONFIG_URL="$BASE_URL/configs/$CONFIG_TEMPLATE.json"
        curl -s "$CONFIG_URL" > "$TEMP_DIR/config.json"
        echo "Configuration template downloaded: $CONFIG_URL"
        echo "Manual configuration may be required."
    fi

    echo "Installation completed successfully!"
fi


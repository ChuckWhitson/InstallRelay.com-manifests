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
APP_NAME="GitHub Desktop"
VERSION="3.4.7"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    VENDOR_URL="https://central.github.com/deployments/desktop/desktop/latest/darwin-arm64"
    INSTALLER_NAME="GitHubDesktop-darwin-arm64.zip"
else
    VENDOR_URL="https://central.github.com/deployments/desktop/desktop/latest/darwin"
    INSTALLER_NAME="GitHubDesktop-darwin.zip"
fi

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
    echo "[WTF] Would download installer from GitHub..."
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
    
    echo "[WTF] Would extract ZIP and copy GitHub Desktop.app to /Applications/"
    echo "[WTF] Installation test completed - no changes made"
else
    # Download installer directly from GitHub
    INSTALLER_PATH="$TEMP_DIR/$INSTALLER_NAME"
    echo "Downloading installer from GitHub..."
    curl -L "$VENDOR_URL" -o "$INSTALLER_PATH"

    if [ ! -f "$INSTALLER_PATH" ]; then
        echo "Error: Failed to download installer"
        exit 1
    fi

    # Extract ZIP
    echo "Extracting installer..."
    cd "$TEMP_DIR"
    unzip -q "$INSTALLER_NAME"

    # Find and copy the application
    if [ -d "$TEMP_DIR/GitHub Desktop.app" ]; then
        if [ -d "/Applications/GitHub Desktop.app" ]; then
            echo "Removing existing GitHub Desktop installation..."
            rm -rf "/Applications/GitHub Desktop.app"
        fi
        cp -R "$TEMP_DIR/GitHub Desktop.app" /Applications/
    else
        echo "Error: Could not find GitHub Desktop.app in ZIP"
        exit 1
    fi

    echo "Installation completed successfully!"
    echo "GitHub Desktop is now available in /Applications"
fi



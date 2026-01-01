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

APP_NAME="PowerShell"
VERSION="7.5.0"
TEMP_DIR=$(mktemp -d)

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    INSTALLER_NAME="powershell-7.5.0-osx-arm64.pkg"
    VENDOR_URL="https://github.com/PowerShell/PowerShell/releases/download/v7.5.0/powershell-7.5.0-osx-arm64.pkg"
else
    INSTALLER_NAME="powershell-7.5.0-osx-x64.pkg"
    VENDOR_URL="https://github.com/PowerShell/PowerShell/releases/download/v7.5.0/powershell-7.5.0-osx-x64.pkg"
fi

INSTALLER_PATH="$TEMP_DIR/$INSTALLER_NAME"

# Cleanup function
cleanup() {
    if [ "$WTF" != true ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

if [ "$WTF" = true ]; then
    echo "[WTF] Would install: $APP_NAME $VERSION"
else
    echo "Installing $APP_NAME $VERSION..."
fi
echo "Detected architecture: $ARCH"

if [ "$WTF" = true ]; then
    echo "[WTF] Would download installer from GitHub..."
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
    
    echo "[WTF] Would install using: sudo installer -pkg \"$INSTALLER_PATH\" -target /"
    echo "[WTF] Installation test completed - no changes made"
else
    # Download installer
    echo "Downloading installer from GitHub..."
    if ! curl -L -o "$INSTALLER_PATH" "$VENDOR_URL"; then
        echo "Failed to download installer" >&2
        exit 1
    fi

    # Install package
    echo "Installing $APP_NAME..."
    if sudo installer -pkg "$INSTALLER_PATH" -target /; then
        echo "Installation completed successfully!"
        echo "PowerShell $VERSION is now available as 'pwsh'"
    else
        echo "Installation failed" >&2
        exit 1
    fi
fi


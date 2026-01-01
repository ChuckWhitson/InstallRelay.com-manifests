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
            CONFIG_TEMPLATE="${arg:-default}"
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
VERSION="3.69.5"
CONFIG_TEMPLATE="${CONFIG_TEMPLATE:-default}"

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    INSTALLER_NAME="FileZilla_3.69.5_macos-arm64.app.tar.bz2"
    VENDOR_URL="https://dl2.cdn.filezilla-project.org/client/FileZilla_3.69.5_macos-arm64.app.tar.bz2?h=zP4hwEapBZehSgiPK7akEg&x=1767260775"
else
    INSTALLER_NAME="FileZilla_3.69.5_macos-x86.app.tar.bz2"
    VENDOR_URL="https://dl2.cdn.filezilla-project.org/client/FileZilla_3.69.5_macos-x86.app.tar.bz2?h=_6EiHXwYqsoRREZflCemmQ&x=1767260775"
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
    
    echo "[WTF] Would extract tar.bz2 and copy FileZilla.app to /Applications/"
    if [ -n "$CONFIG_TEMPLATE" ]; then
        echo "[WTF] Would apply configuration template: $CONFIG_TEMPLATE"
    fi
    echo "[WTF] Installation test completed - no changes made"
else
    # Download installer directly from FileZilla website
    INSTALLER_PATH="$TEMP_DIR/$INSTALLER_NAME"
    echo "Downloading installer from FileZilla website..."
    curl -L "$VENDOR_URL" -o "$INSTALLER_PATH"

    if [ ! -f "$INSTALLER_PATH" ]; then
        echo "Error: Failed to download installer"
        exit 1
    fi

    # Extract tar.bz2
    echo "Extracting installer..."
    cd "$TEMP_DIR"
    tar -xjf "$INSTALLER_NAME"

    # Find and copy the application
    if [ -d "$TEMP_DIR/FileZilla.app" ]; then
        if [ -d "/Applications/FileZilla.app" ]; then
            echo "Removing existing FileZilla installation..."
            rm -rf "/Applications/FileZilla.app"
        fi
        cp -R "$TEMP_DIR/FileZilla.app" /Applications/
    else
        echo "Error: Could not find FileZilla.app in archive"
        exit 1
    fi

    # Apply configuration if specified
    if [ -n "$CONFIG_TEMPLATE" ]; then
        echo "Applying $CONFIG_TEMPLATE configuration..."
        echo "Configuration template: $CONFIG_TEMPLATE"
        echo "Manual configuration may be required."
    fi

    echo "Installation completed successfully!"
    echo "FileZilla is now available in /Applications"
fi



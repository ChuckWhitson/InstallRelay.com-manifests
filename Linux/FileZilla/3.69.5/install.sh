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

INSTALLER_NAME="FileZilla_3.69.5_x86_64-linux-gnu.tar.xz"
VENDOR_URL="https://dl2.cdn.filezilla-project.org/client/FileZilla_3.69.5_x86_64-linux-gnu.tar.xz?h=uhjstG8W22Tv5hGzMeXgfA&x=1767260775"

if [ "$WTF" != true ]; then
    TEMP_DIR=$(mktemp -d)
    INSTALL_DIR="/opt/filezilla"
    trap "rm -rf $TEMP_DIR" EXIT
else
    TEMP_DIR="/tmp/wtf-test"
    INSTALL_DIR="/opt/filezilla"
fi

# Check if running as root (skip in WTF mode)
if [ "$WTF" != true ] && [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

if [ "$WTF" = true ]; then
    echo "[WTF] Would install: $APP_NAME $VERSION"
else
    echo "Installing $APP_NAME $VERSION..."
fi

if [ "$WTF" = true ]; then
    echo "[WTF] Would try package manager first (apt-get)"
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
    
    echo "[WTF] Would extract tar.xz to $INSTALL_DIR and create symlink"
    if [ -n "$CONFIG_TEMPLATE" ]; then
        echo "[WTF] Would apply configuration template: $CONFIG_TEMPLATE"
    fi
    echo "[WTF] Installation test completed - no changes made"
else
    # Try package manager first
    if command -v apt-get &> /dev/null; then
        echo "Installing via apt-get..."
        apt-get update && apt-get install -y filezilla
        if [ $? -eq 0 ]; then
            echo "Installation completed successfully via package manager!"
            exit 0
        fi
    fi

    # Fallback to direct download from FileZilla website
    echo "Downloading installer from FileZilla website..."
    INSTALLER_PATH="$TEMP_DIR/$INSTALLER_NAME"
    curl -L "$VENDOR_URL" -o "$INSTALLER_PATH"

    if [ ! -f "$INSTALLER_PATH" ]; then
        echo "Error: Failed to download installer"
        exit 1
    fi

    # Extract and install
    echo "Extracting and installing..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi
    mkdir -p "$INSTALL_DIR"
    tar -xJf "$INSTALLER_PATH" -C "$INSTALL_DIR" --strip-components=1

    # Create symlink
    if [ -f "$INSTALL_DIR/bin/filezilla" ]; then
        ln -sf "$INSTALL_DIR/bin/filezilla" /usr/local/bin/filezilla
    fi

    # Apply configuration if specified
    if [ -n "$CONFIG_TEMPLATE" ]; then
        echo "Applying $CONFIG_TEMPLATE configuration..."
        echo "Configuration template: $CONFIG_TEMPLATE"
        echo "Manual configuration may be required."
    fi

    echo "Installation completed successfully!"
fi



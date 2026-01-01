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
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    INSTALLER_NAME="FileZilla_3.67.1_aarch64-linux-gnu.tar.bz2"
    VENDOR_URL="https://download.filezilla-project.org/client/FileZilla_3.67.1_aarch64-linux-gnu.tar.bz2"
else
    INSTALLER_NAME="FileZilla_3.67.1_x86_64-linux-gnu.tar.bz2"
    VENDOR_URL="https://download.filezilla-project.org/client/FileZilla_3.67.1_x86_64-linux-gnu.tar.bz2"
fi

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
    
    echo "[WTF] Would extract to $INSTALL_DIR and create symlink"
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

    # Extract and install
    echo "Extracting and installing..."
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi
    mkdir -p "$INSTALL_DIR"
    tar -xjf "$INSTALLER_PATH" -C "$INSTALL_DIR" --strip-components=1

    # Create symlink
    ln -sf "$INSTALL_DIR/bin/filezilla" /usr/local/bin/filezilla

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


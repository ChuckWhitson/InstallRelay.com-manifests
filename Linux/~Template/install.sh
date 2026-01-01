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

# Check if running as root (skip in WTF mode)
if [ "$WTF" != true ] && [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
# TODO: Update installer names and URLs based on architecture
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    INSTALLER_NAME="app-name-aarch64.deb"
    VENDOR_URL="https://example.com/downloads/app-name-aarch64.deb"
else
    INSTALLER_NAME="app-name-x64.deb"
    VENDOR_URL="https://example.com/downloads/app-name-x64.deb"
fi

if [ "$WTF" != true ]; then
    TEMP_DIR=$(mktemp -d)
    INSTALL_DIR="/opt/app-name"
    trap "rm -rf $TEMP_DIR" EXIT
else
    TEMP_DIR="/tmp/wtf-test"
    INSTALL_DIR="/opt/app-name"
fi

if [ "$WTF" = true ]; then
    echo "[WTF] Would install: $APP_NAME $VERSION"
else
    echo "Installing $APP_NAME $VERSION..."
fi

if [ "$WTF" = true ]; then
    echo "[WTF] Would try package manager first (apt-get/dnf/yum)"
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
    echo "[WTF] Would install package or extract archive to $INSTALL_DIR"
    echo "[WTF] Installation test completed - no changes made"
else
    # Try package manager first (if applicable)
    # TODO: Update package name if available via package manager
    if command -v apt-get &> /dev/null; then
        echo "Trying to install via apt-get..."
        # apt-get update && apt-get install -y package-name
        # if [ $? -eq 0 ]; then
        #     echo "Installation completed successfully via package manager!"
        #     exit 0
        # fi
    fi

    # Fallback to direct download from vendor
    echo "Downloading installer from vendor..."
    INSTALLER_PATH="$TEMP_DIR/$INSTALLER_NAME"
    curl -L "$VENDOR_URL" -o "$INSTALLER_PATH"

    if [ ! -f "$INSTALLER_PATH" ]; then
        echo "Error: Failed to download installer"
        exit 1
    fi

    # Install based on file type
    # TODO: Update installation steps based on your application type (.deb, .rpm, .tar.gz, etc.)
    if [[ "$INSTALLER_NAME" == *.deb ]]; then
        echo "Installing .deb package..."
        dpkg -i "$INSTALLER_PATH" || apt-get install -f -y
    elif [[ "$INSTALLER_NAME" == *.rpm ]]; then
        echo "Installing .rpm package..."
        rpm -i "$INSTALLER_PATH" || yum install -y "$INSTALLER_PATH"
    elif [[ "$INSTALLER_NAME" == *.tar.gz ]] || [[ "$INSTALLER_NAME" == *.tar.xz ]]; then
        echo "Extracting and installing..."
        if [ -d "$INSTALL_DIR" ]; then
            rm -rf "$INSTALL_DIR"
        fi
        mkdir -p "$INSTALL_DIR"
        tar -xzf "$INSTALLER_PATH" -C "$INSTALL_DIR" --strip-components=1
        
        # Create symlink if needed
        # TODO: Update binary path
        # if [ -f "$INSTALL_DIR/bin/app-name" ]; then
        #     ln -sf "$INSTALL_DIR/bin/app-name" /usr/local/bin/app-name
        # fi
    else
        echo "Error: Unsupported installer format"
        exit 1
    fi

    echo "Installation completed successfully!"
fi


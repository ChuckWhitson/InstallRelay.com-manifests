#!/bin/bash
set -e

# Install Mozilla Firefox on Linux
# Attempts to use package manager first, falls back to direct download

APP_NAME="Mozilla Firefox"
VENDOR_URL="https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US"
TARBALL_NAME="firefox-latest.tar.bz2"
INSTALL_DIR="/opt/firefox"
TEMP_DIR=$(mktemp -d)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    rm -rf "$TEMP_DIR"
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo -e "${GREEN}Installing $APP_NAME...${NC}"
echo ""

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    echo -e "${YELLOW}Detected distribution: $DISTRO${NC}"
else
    echo -e "${YELLOW}Could not detect distribution, will try package managers${NC}"
    DISTRO="unknown"
fi

echo ""

# Function to install via package manager
install_via_package_manager() {
    local pkg_manager=$1
    local install_cmd=$2
    
    if command -v "$pkg_manager" &> /dev/null; then
        echo -e "${YELLOW}Installing Firefox via $pkg_manager...${NC}"
        eval "$install_cmd"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Firefox installed successfully via $pkg_manager!${NC}"
            return 0
        else
            echo -e "${YELLOW}Package manager installation failed, trying direct download...${NC}"
            return 1
        fi
    fi
    return 1
}

# Try package manager installation first
INSTALLED=false

# Try apt (Debian/Ubuntu)
if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ] || command -v apt-get &> /dev/null; then
    if install_via_package_manager "apt-get" "apt-get update && apt-get install -y firefox"; then
        INSTALLED=true
    fi
fi

# Try yum (RHEL/CentOS 7)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ] || command -v yum &> /dev/null); then
    if install_via_package_manager "yum" "yum install -y firefox"; then
        INSTALLED=true
    fi
fi

# Try dnf (Fedora/RHEL 8+/CentOS 8+)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "fedora" ] || command -v dnf &> /dev/null); then
    if install_via_package_manager "dnf" "dnf install -y firefox"; then
        INSTALLED=true
    fi
fi

# Try zypper (openSUSE)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "opensuse" ] || [ "$DISTRO" = "sles" ] || command -v zypper &> /dev/null); then
    if install_via_package_manager "zypper" "zypper install -y MozillaFirefox"; then
        INSTALLED=true
    fi
fi

# If package manager installation failed, download directly from Mozilla
if [ "$INSTALLED" = false ]; then
    echo -e "${YELLOW}Package manager installation not available or failed${NC}"
    echo -e "${YELLOW}Downloading Firefox directly from Mozilla...${NC}"
    
    TARBALL_PATH="$TEMP_DIR/$TARBALL_NAME"
    curl -L "$VENDOR_URL" -o "$TARBALL_PATH"
    
    if [ ! -f "$TARBALL_PATH" ]; then
        echo -e "${RED}Failed to download Firefox${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Downloaded Firefox: $TARBALL_PATH${NC}"
    echo ""
    
    # Extract to /opt/firefox
    echo -e "${YELLOW}Extracting Firefox to $INSTALL_DIR...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi
    mkdir -p "$INSTALL_DIR"
    tar -xjf "$TARBALL_PATH" -C "$INSTALL_DIR" --strip-components=1
    
    # Create symlink in /usr/local/bin
    echo -e "${YELLOW}Creating symlink...${NC}"
    ln -sf "$INSTALL_DIR/firefox" /usr/local/bin/firefox
    
    # Create desktop entry
    echo -e "${YELLOW}Creating desktop entry...${NC}"
    DESKTOP_DIR="/usr/share/applications"
    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_DIR/firefox.desktop" <<EOF
[Desktop Entry]
Name=Firefox
Comment=Browse the Web
GenericName=Web Browser
Exec=$INSTALL_DIR/firefox %u
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=$INSTALL_DIR/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
EOF
    
    echo ""
    echo -e "${GREEN}Firefox installed successfully to $INSTALL_DIR!${NC}"
    echo -e "${GREEN}Run 'firefox' to start Firefox${NC}"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"


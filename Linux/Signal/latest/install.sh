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

# Install Signal Desktop on Linux
# Uses Signal's official APT repository

APP_NAME="Signal Desktop"
VERSION="latest"

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root (skip in WTF mode)
if [ "$WTF" != true ] && [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

if [ "$WTF" = true ]; then
    echo -e "${GREEN}[WTF] Would install: $APP_NAME${NC}"
else
    echo -e "${GREEN}Installing $APP_NAME...${NC}"
fi
echo ""

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    echo -e "${YELLOW}Detected distribution: $DISTRO${NC}"
else
    echo -e "${YELLOW}Could not detect distribution${NC}"
    DISTRO="unknown"
fi

echo ""

# Function to install via APT (Debian/Ubuntu)
install_via_apt() {
    if command -v apt-get &> /dev/null; then
        echo -e "${YELLOW}Installing Signal Desktop via APT repository...${NC}"
        
        # Install required dependencies
        apt-get update
        apt-get install -y wget gpg
        
        # Install the official public software signing key
        echo -e "${YELLOW}Adding Signal's GPG key...${NC}"
        wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /tmp/signal-desktop-keyring.gpg
        mv /tmp/signal-desktop-keyring.gpg /usr/share/keyrings/signal-desktop-keyring.gpg
        
        # Add the repository
        echo -e "${YELLOW}Adding Signal's APT repository...${NC}"
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" > /etc/apt/sources.list.d/signal-xenial.list
        
        # Update package database and install
        apt-get update
        apt-get install -y signal-desktop
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Signal Desktop installed successfully!${NC}"
            return 0
        else
            echo -e "${RED}Installation failed${NC}"
            return 1
        fi
    fi
    return 1
}

# Function to install via DNF/YUM (Fedora/RHEL)
install_via_dnf() {
    if command -v dnf &> /dev/null; then
        echo -e "${YELLOW}Installing Signal Desktop via DNF repository...${NC}"
        
        # Install required dependencies
        dnf install -y wget
        
        # Add Signal's repository
        echo -e "${YELLOW}Adding Signal's DNF repository...${NC}"
        cat > /etc/yum.repos.d/signal-desktop.repo << EOF
[signal-desktop]
name=Signal Desktop
baseurl=https://updates.signal.org/desktop/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://updates.signal.org/desktop/rpm/keys.asc
EOF
        
        # Install Signal Desktop
        dnf install -y signal-desktop
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Signal Desktop installed successfully!${NC}"
            return 0
        else
            echo -e "${RED}Installation failed${NC}"
            return 1
        fi
    elif command -v yum &> /dev/null; then
        echo -e "${YELLOW}Installing Signal Desktop via YUM repository...${NC}"
        
        # Install required dependencies
        yum install -y wget
        
        # Add Signal's repository
        echo -e "${YELLOW}Adding Signal's YUM repository...${NC}"
        cat > /etc/yum.repos.d/signal-desktop.repo << EOF
[signal-desktop]
name=Signal Desktop
baseurl=https://updates.signal.org/desktop/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://updates.signal.org/desktop/rpm/keys.asc
EOF
        
        # Install Signal Desktop
        yum install -y signal-desktop
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Signal Desktop installed successfully!${NC}"
            return 0
        else
            echo -e "${RED}Installation failed${NC}"
            return 1
        fi
    fi
    return 1
}

if [ "$WTF" = true ]; then
    echo -e "${YELLOW}[WTF] Would detect distribution and try package managers:${NC}"
    echo -e "${YELLOW}[WTF]   - apt-get (Debian/Ubuntu)${NC}"
    echo -e "${YELLOW}[WTF]   - dnf/yum (Fedora/RHEL/CentOS)${NC}"
    echo -e "${YELLOW}[WTF] Would add Signal repository and install signal-desktop package${NC}"
    echo -e "${GREEN}[WTF] Installation test completed - no changes made${NC}"
    exit 0
fi

INSTALLED=false

# Try APT first (Debian/Ubuntu)
if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ] || command -v apt-get &> /dev/null; then
    if install_via_apt; then
        INSTALLED=true
    fi
fi

# Try DNF/YUM (Fedora/RHEL/CentOS)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ] || command -v dnf &> /dev/null || command -v yum &> /dev/null); then
    if install_via_dnf; then
        INSTALLED=true
    fi
fi

if [ "$INSTALLED" = false ]; then
    echo -e "${RED}Failed to install Signal Desktop${NC}"
    echo -e "${YELLOW}Please visit https://signal.org/download/linux/ for manual installation instructions${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${YELLOW}Please open Signal and link it with your mobile device.${NC}"


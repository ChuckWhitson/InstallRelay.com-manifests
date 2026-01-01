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

# Install Google Drive client for Linux
# Note: Google does not provide an official Linux client
# This script installs Insync, a third-party Google Drive client

APP_NAME="Google Drive (via Insync)"
VERSION="2025.01.15"

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
    echo -e "${GREEN}[WTF] Would install: $APP_NAME $VERSION${NC}"
else
    echo -e "${GREEN}Installing $APP_NAME $VERSION...${NC}"
fi
echo -e "${YELLOW}Note: Google does not provide an official Linux client.${NC}"
echo -e "${YELLOW}This script installs Insync, a third-party Google Drive client.${NC}"
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

# Function to install Insync via package manager
install_insync() {
    local pkg_manager=$1
    local install_cmd=$2
    
    if command -v "$pkg_manager" &> /dev/null; then
        echo -e "${YELLOW}Installing Insync via $pkg_manager...${NC}"
        eval "$install_cmd"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Insync installed successfully!${NC}"
            return 0
        else
            echo -e "${YELLOW}Package manager installation failed${NC}"
            return 1
        fi
    fi
    return 1
}

if [ "$WTF" = true ]; then
    echo -e "${YELLOW}[WTF] Would detect distribution and try package managers:${NC}"
    echo -e "${YELLOW}[WTF]   - apt-get (Debian/Ubuntu)${NC}"
    echo -e "${YELLOW}[WTF]   - yum (RHEL/CentOS 7)${NC}"
    echo -e "${YELLOW}[WTF]   - dnf (Fedora/RHEL 8+)${NC}"
    echo -e "${YELLOW}[WTF] Would add Insync repository and install insync package${NC}"
    echo -e "${GREEN}[WTF] Installation test completed - no changes made${NC}"
    exit 0
fi

INSTALLED=false

# Try apt (Debian/Ubuntu)
if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ] || command -v apt-get &> /dev/null; then
    echo -e "${YELLOW}Adding Insync repository for Debian/Ubuntu...${NC}"
    
    # Add Insync repository
    if ! grep -q "insync" /etc/apt/sources.list.d/insync.list 2>/dev/null; then
        echo "deb http://apt.insync.io/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) non-free contrib" | tee /etc/apt/sources.list.d/insync.list > /dev/null
        curl -fsSL https://d2t3ff60b2tol4.cloudfront.net/services@insynchq.com.gpg.key | apt-key add - > /dev/null 2>&1
        apt-get update > /dev/null 2>&1
    fi
    
    if install_insync "apt-get" "apt-get install -y insync"; then
        INSTALLED=true
    fi
fi

# Try yum (RHEL/CentOS 7)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ] || command -v yum &> /dev/null); then
    echo -e "${YELLOW}Adding Insync repository for RHEL/CentOS...${NC}"
    
    if [ ! -f /etc/yum.repos.d/insync.repo ]; then
        cat > /etc/yum.repos.d/insync.repo << EOF
[insync]
name=Insync Repository
baseurl=http://yum.insync.io/fedora/\$releasever/
gpgcheck=1
gpgkey=https://d2t3ff60b2tol4.cloudfront.net/services@insynchq.com.gpg.key
enabled=1
EOF
    fi
    
    if install_insync "yum" "yum install -y insync"; then
        INSTALLED=true
    fi
fi

# Try dnf (Fedora/RHEL 8+/CentOS 8+)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "fedora" ] || command -v dnf &> /dev/null); then
    echo -e "${YELLOW}Adding Insync repository for Fedora...${NC}"
    
    if [ ! -f /etc/yum.repos.d/insync.repo ]; then
        cat > /etc/yum.repos.d/insync.repo << EOF
[insync]
name=Insync Repository
baseurl=http://yum.insync.io/fedora/\$releasever/
gpgcheck=1
gpgkey=https://d2t3ff60b2tol4.cloudfront.net/services@insynchq.com.gpg.key
enabled=1
EOF
    fi
    
    if install_insync "dnf" "dnf install -y insync"; then
        INSTALLED=true
    fi
fi

if [ "$INSTALLED" = false ]; then
    echo -e "${RED}Failed to install Insync via package manager${NC}"
    echo -e "${YELLOW}Please visit https://www.insynchq.com/downloads to download Insync manually${NC}"
    echo -e "${YELLOW}Note: Insync is a paid application (free trial available)${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "${YELLOW}Please launch Insync and sign in with your Google account to start syncing.${NC}"
echo -e "${YELLOW}Note: Insync requires a license (free trial available).${NC}"


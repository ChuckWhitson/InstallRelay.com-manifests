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

# Install LibreOffice on Linux
# Attempts to use package manager first, falls back to direct download

APP_NAME="LibreOffice"
VERSION="25.2.7"

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
    TEMP_DIR="/tmp/wtf-test"
    INSTALL_DIR="/opt/libreoffice"
else
    TEMP_DIR=$(mktemp -d)
    INSTALL_DIR="/opt/libreoffice"
    
    # Cleanup function
    cleanup() {
        echo -e "${YELLOW}Cleaning up...${NC}"
        rm -rf "$TEMP_DIR"
    }
    
    # Set trap to cleanup on exit
    trap cleanup EXIT
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
        echo -e "${YELLOW}Installing LibreOffice via $pkg_manager...${NC}"
        eval "$install_cmd"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}LibreOffice installed successfully via $pkg_manager!${NC}"
            return 0
        else
            echo -e "${YELLOW}Package manager installation failed, trying direct download...${NC}"
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
    echo -e "${YELLOW}[WTF]   - zypper (openSUSE)${NC}"
    echo -e "${YELLOW}[WTF] Would fallback to direct download from LibreOffice if package manager fails${NC}"
    echo -e "${YELLOW}[WTF] Would download and install DEB or RPM packages${NC}"
    echo -e "${GREEN}[WTF] Installation test completed - no changes made${NC}"
    exit 0
fi

# Try package manager installation first
INSTALLED=false

# Try apt (Debian/Ubuntu)
if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ] || command -v apt-get &> /dev/null; then
    if install_via_package_manager "apt-get" "apt-get update && apt-get install -y libreoffice"; then
        INSTALLED=true
    fi
fi

# Try yum (RHEL/CentOS 7)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ] || command -v yum &> /dev/null); then
    if install_via_package_manager "yum" "yum install -y libreoffice"; then
        INSTALLED=true
    fi
fi

# Try dnf (Fedora/RHEL 8+/CentOS 8+)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "fedora" ] || command -v dnf &> /dev/null); then
    if install_via_package_manager "dnf" "dnf install -y libreoffice"; then
        INSTALLED=true
    fi
fi

# Try zypper (openSUSE)
if [ "$INSTALLED" = false ] && ([ "$DISTRO" = "opensuse" ] || [ "$DISTRO" = "sles" ] || command -v zypper &> /dev/null); then
    if install_via_package_manager "zypper" "zypper install -y libreoffice"; then
        INSTALLED=true
    fi
fi

# If package manager installation failed, download directly from LibreOffice
if [ "$INSTALLED" = false ]; then
    echo -e "${YELLOW}Package manager installation not available or failed${NC}"
    echo -e "${YELLOW}Downloading LibreOffice directly from LibreOffice website...${NC}"
    
    # Determine package type based on distribution
    if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ] || command -v dpkg &> /dev/null; then
        TARBALL_NAME="LibreOffice_25.2.7_Linux_x86-64_deb.tar.gz"
        VENDOR_URL="https://download.libreoffice.org/libreoffice/stable/25.2.7/deb/x86_64/LibreOffice_25.2.7_Linux_x86-64_deb.tar.gz"
    else
        TARBALL_NAME="LibreOffice_25.2.7_Linux_x86-64_rpm.tar.gz"
        VENDOR_URL="https://download.libreoffice.org/libreoffice/stable/25.2.7/rpm/x86_64/LibreOffice_25.2.7_Linux_x86-64_rpm.tar.gz"
    fi
    
    TARBALL_PATH="$TEMP_DIR/$TARBALL_NAME"
    curl -L "$VENDOR_URL" -o "$TARBALL_PATH"
    
    if [ ! -f "$TARBALL_PATH" ]; then
        echo -e "${RED}Failed to download LibreOffice${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Downloaded LibreOffice: $TARBALL_PATH${NC}"
    echo ""
    
    # Extract tarball
    echo -e "${YELLOW}Extracting LibreOffice...${NC}"
    cd "$TEMP_DIR"
    tar -xzf "$TARBALL_NAME"
    
    # Install DEB packages
    if [ -d "$TEMP_DIR/LibreOffice_25.2.7.2_Linux_x86-64_deb" ]; then
        echo -e "${YELLOW}Installing DEB packages...${NC}"
        cd "$TEMP_DIR/LibreOffice_25.2.7.2_Linux_x86-64_deb/DEBS"
        dpkg -i *.deb
    # Install RPM packages
    elif [ -d "$TEMP_DIR/LibreOffice_25.2.7.2_Linux_x86-64_rpm" ]; then
        echo -e "${YELLOW}Installing RPM packages...${NC}"
        cd "$TEMP_DIR/LibreOffice_25.2.7.2_Linux_x86-64_rpm/RPMS"
        rpm -Uvh *.rpm
    else
        echo -e "${RED}Could not find installation packages in tarball${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}LibreOffice $VERSION installed successfully!${NC}"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"


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

# WTF? mode - Test everything without making changes
if [ "$WTF" = true ]; then
    echo "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ==="
    echo ""
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect Linux distribution" >&2
    exit 1
fi

if [ "$WTF" = true ]; then
    echo "[WTF] Would install: $APP_NAME $VERSION"
else
    echo "Installing $APP_NAME $VERSION..."
fi
echo "Detected distribution: $DISTRO"

# Function to install on Debian/Ubuntu
install_debian() {
    if [ "$WTF" = true ]; then
        echo "[WTF] Would update package list"
        echo "[WTF] Would install prerequisites: wget apt-transport-https software-properties-common lsb-release"
        
        if command -v lsb_release &> /dev/null; then
            UBUNTU_VERSION=$(lsb_release -rs)
        else
            UBUNTU_VERSION="22.04"
        fi
        echo "[WTF] Would download Microsoft repository GPG keys for Ubuntu $UBUNTU_VERSION"
        echo "[WTF] Would add Microsoft repository"
        echo "[WTF] Would install PowerShell via apt-get"
        return 0
    fi
    
    # Update package list
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y wget apt-transport-https software-properties-common lsb-release
    
    # Detect Ubuntu version or use default
    if command -v lsb_release &> /dev/null; then
        UBUNTU_VERSION=$(lsb_release -rs)
    else
        # Default to 22.04 if lsb_release not available
        UBUNTU_VERSION="22.04"
    fi
    
    # Download Microsoft repository GPG keys
    wget -q "https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
    sudo dpkg -i /tmp/packages-microsoft-prod.deb
    rm /tmp/packages-microsoft-prod.deb
    
    # Update package list
    sudo apt-get update
    
    # Install PowerShell
    sudo apt-get install -y powershell
}

# Function to install on RHEL/CentOS/Fedora
install_rhel() {
    if [ "$WTF" = true ]; then
        if command -v dnf &> /dev/null; then
            echo "[WTF] Would add Microsoft repository for RHEL 8+"
            echo "[WTF] Would install PowerShell via dnf"
        elif command -v yum &> /dev/null; then
            echo "[WTF] Would add Microsoft repository for RHEL 7"
            echo "[WTF] Would install PowerShell via yum"
        fi
        return 0
    fi
    
    if command -v dnf &> /dev/null; then
        # Fedora/RHEL 8+
        sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
        sudo dnf install -y powershell
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS 7
        sudo yum install -y https://packages.microsoft.com/config/rhel/7/packages-microsoft-prod.rpm
        sudo yum install -y powershell
    else
        echo "Unsupported package manager" >&2
        exit 1
    fi
}

# Function to install on openSUSE
install_opensuse() {
    if [ "$WTF" = true ]; then
        echo "[WTF] Would add Microsoft repository for openSUSE"
        echo "[WTF] Would refresh repository"
        echo "[WTF] Would install PowerShell via zypper"
        return 0
    fi
    
    sudo zypper addrepo https://packages.microsoft.com/config/opensuse/15/prod.repo
    sudo zypper --gpg-auto-import-keys refresh
    sudo zypper install -y powershell
}

# Install based on distribution
case $DISTRO in
    ubuntu|debian)
        install_debian
        ;;
    rhel|centos|fedora)
        install_rhel
        ;;
    opensuse*|sles)
        install_opensuse
        ;;
    *)
        echo "Unsupported distribution: $DISTRO" >&2
        echo "Attempting generic installation via Microsoft repository..." >&2
        
        # Try Debian method as fallback
        if command -v apt-get &> /dev/null; then
            install_debian
        else
            echo "Cannot determine installation method for $DISTRO" >&2
            exit 1
        fi
        ;;
esac

# Verify installation (skip in WTF mode)
if [ "$WTF" = true ]; then
    echo "[WTF] Installation test completed - no changes made"
else
    if command -v pwsh &> /dev/null; then
        echo "Installation completed successfully!"
        echo "PowerShell is now available as 'pwsh'"
        pwsh --version
    elif [ -f /usr/bin/pwsh ]; then
        echo "Installation completed successfully!"
        echo "PowerShell is installed at /usr/bin/pwsh"
        /usr/bin/pwsh --version
    else
        echo "Installation completed, but 'pwsh' command not found" >&2
        echo "You may need to restart your terminal or check the installation" >&2
        echo "PowerShell may be installed but not in PATH yet" >&2
        # Don't exit with error - installation may have succeeded but PATH needs refresh
    fi
fi


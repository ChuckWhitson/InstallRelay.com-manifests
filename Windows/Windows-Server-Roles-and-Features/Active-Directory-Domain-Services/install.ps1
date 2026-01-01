# Install Active Directory Domain Services (AD DS) Role
# This script detects OS version and prompts for necessary information

param(
    [string]$DomainName = "",
    [string]$NetBIOSName = "",
    [string]$SafeModePassword = "",
    [switch]$SkipPrompts = $false,
    [switch]$WTF
)

$ErrorActionPreference = "Stop"

# Check for WTF environment variable if parameter not provided
if (-not $WTF -and $env:INSTALLRELAY_WTF -eq "1") {
    $WTF = $true
}

# WTF? mode - Test everything without making changes
if ($WTF) {
    Write-Host "=== WTF? MODE ENABLED - TESTING ONLY, NO CHANGES WILL BE MADE ===" -ForegroundColor Yellow
    Write-Host ""
}

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to detect OS version
function Get-OSVersion {
    $os = Get-CimInstance Win32_OperatingSystem
    $version = [Version]$os.Version
    $build = $os.BuildNumber
    
    Write-ColorOutput "Detected OS Information:" "Cyan"
    Write-ColorOutput "  OS Name: $($os.Caption)" "Gray"
    Write-ColorOutput "  Version: $version" "Gray"
    Write-ColorOutput "  Build: $build" "Gray"
    Write-ColorOutput ""
    
    # Check if it's Windows Server
    if ($os.Caption -notmatch "Server") {
        throw "This script requires Windows Server. Detected OS: $($os.Caption)"
    }
    
    # Check minimum version (Windows Server 2019 = 10.0.17763)
    if ($version -lt [Version]"10.0.17763") {
        throw "This script requires Windows Server 2019 or later. Detected version: $version"
    }
    
    return @{
        Version = $version
        Build = $build
        Caption = $os.Caption
        IsServer = $true
    }
}

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to prompt for domain information
function Get-DomainInformation {
    param([bool]$SkipPrompts)
    
    if ($SkipPrompts -and $DomainName -and $NetBIOSName -and $SafeModePassword) {
        return @{
            DomainName = $DomainName
            NetBIOSName = $NetBIOSName
            SafeModePassword = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force
        }
    }
    
    Write-ColorOutput "==========================================" "Yellow"
    Write-ColorOutput "Active Directory Domain Services Setup" "Yellow"
    Write-ColorOutput "==========================================" "Yellow"
    Write-ColorOutput ""
    
    # Prompt for domain name
    if (-not $DomainName) {
        Write-ColorOutput "Enter the fully qualified domain name (FQDN) for the new domain:" "Cyan"
        Write-ColorOutput "Example: contoso.com" "Gray"
        $DomainName = Read-Host "Domain FQDN"
    }
    
    if ([string]::IsNullOrWhiteSpace($DomainName)) {
        throw "Domain name is required"
    }
    
    # Prompt for NetBIOS name
    if (-not $NetBIOSName) {
        Write-ColorOutput ""
        Write-ColorOutput "Enter the NetBIOS name for the domain:" "Cyan"
        Write-ColorOutput "Example: CONTOSO" "Gray"
        $NetBIOSName = Read-Host "NetBIOS Name"
    }
    
    if ([string]::IsNullOrWhiteSpace($NetBIOSName)) {
        # Auto-generate from domain name
        $NetBIOSName = $DomainName.Split('.')[0].ToUpper()
        Write-ColorOutput "Using auto-generated NetBIOS name: $NetBIOSName" "Yellow"
    }
    
    # Prompt for Safe Mode Administrator password
    if (-not $SafeModePassword) {
        Write-ColorOutput ""
        Write-ColorOutput "Enter the Safe Mode Administrator password:" "Cyan"
        Write-ColorOutput "This password is used for Directory Services Restore Mode" "Gray"
        $securePassword = Read-Host "Safe Mode Password" -AsSecureString
    } else {
        $securePassword = ConvertTo-SecureString $SafeModePassword -AsPlainText -Force
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "Configuration Summary:" "Green"
    Write-ColorOutput "  Domain FQDN: $DomainName" "Gray"
    Write-ColorOutput "  NetBIOS Name: $NetBIOSName" "Gray"
    Write-ColorOutput ""
    
    return @{
        DomainName = $DomainName
        NetBIOSName = $NetBIOSName
        SafeModePassword = $securePassword
    }
}

# Main installation process
try {
    Write-ColorOutput "==========================================" "Green"
    Write-ColorOutput "AD DS Role Installation Script" "Green"
    Write-ColorOutput "==========================================" "Green"
    Write-ColorOutput ""
    
    # Check if running as Administrator
    if (-not (Test-Administrator)) {
        throw "This script must be run as Administrator. Please restart PowerShell as Administrator."
    }
    
    # Detect OS version
    $osInfo = Get-OSVersion
    
    # Get domain information
    $domainInfo = Get-DomainInformation -SkipPrompts $SkipPrompts
    
    # Check if AD DS is already installed
    Write-ColorOutput "Checking if AD DS is already installed..." "Yellow"
    $addsFeature = Get-WindowsFeature -Name AD-Domain-Services
    
    if ($addsFeature.Installed) {
        Write-ColorOutput "AD DS is already installed." "Green"
        Write-ColorOutput "To promote this server to a Domain Controller, use:" "Yellow"
        Write-ColorOutput "  Install-ADDSForest -DomainName '$($domainInfo.DomainName)' -DomainNetbiosName '$($domainInfo.NetBIOSName)' -SafeModeAdministratorPassword `$securePassword" "Gray"
        return
    }
    
    if ($WTF) {
        Write-ColorOutput ""
        Write-ColorOutput "[WTF] Would install AD DS role..." "Yellow"
        Write-ColorOutput "[WTF] Domain FQDN: $($domainInfo.DomainName)" "Gray"
        Write-ColorOutput "[WTF] NetBIOS Name: $($domainInfo.NetBIOSName)" "Gray"
        Write-ColorOutput "[WTF] Would run: Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools" "Gray"
        Write-ColorOutput "[WTF] Installation test completed - no changes made" "Green"
        return
    }
    
    # Install AD DS role
    Write-ColorOutput ""
    Write-ColorOutput "Installing AD DS role..." "Yellow"
    Write-ColorOutput "This may take several minutes..." "Gray"
    
    $result = Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    
    if ($result.Success) {
        Write-ColorOutput ""
        Write-ColorOutput "AD DS role installed successfully!" "Green"
        Write-ColorOutput ""
        Write-ColorOutput "Next Steps:" "Yellow"
        Write-ColorOutput "1. The server will need to be rebooted" "Gray"
        Write-ColorOutput "2. After reboot, promote this server to a Domain Controller using:" "Gray"
        Write-ColorOutput "   Install-ADDSForest -DomainName '$($domainInfo.DomainName)' -DomainNetbiosName '$($domainInfo.NetBIOSName)' -SafeModeAdministratorPassword `$securePassword" "Gray"
        Write-ColorOutput ""
        Write-ColorOutput "Or use Server Manager GUI to complete the promotion." "Gray"
        Write-ColorOutput ""
        
        if ($result.RestartNeeded) {
            Write-ColorOutput "Reboot required. Restart now? (Y/N)" "Yellow"
            $restart = Read-Host
            if ($restart -eq "Y" -or $restart -eq "y") {
                Restart-Computer -Force
            }
        }
    } else {
        throw "Failed to install AD DS role: $($result.RestartNeeded)"
    }
    
} catch {
    Write-ColorOutput ""
    Write-ColorOutput "Error: $_" "Red"
    Write-ColorOutput ""
    Write-ColorOutput "Stack Trace:" "Red"
    Write-ColorOutput $_.ScriptStackTrace "Gray"
    # Don't exit - allow script to continue
    $LASTEXITCODE = 1
}


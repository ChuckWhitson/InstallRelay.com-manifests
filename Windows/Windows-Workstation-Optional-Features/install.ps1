# Install Windows Workstation Optional Features (RSAT Tools)
# This script detects OS version and installs RSAT features for Windows 11

param(
    [string[]]$Features = @(),
    [switch]$InstallAll = $false,
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

# Available RSAT features for Windows 11
$AvailableFeatures = @(
    "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0",
    "Rsat.AzureStack.HCI.Management.Tools~~~~0.0.1.0",
    "Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0",
    "Rsat.CertificateServices.Tools~~~~0.0.1.0",
    "Rsat.DHCP.Tools~~~~0.0.1.0",
    "Rsat.Dns.Tools~~~~0.0.1.0",
    "Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0",
    "Rsat.FileServices.Tools~~~~0.0.1.0",
    "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0",
    "Rsat.IPAM.Client.Tools~~~~0.0.1.0",
    "Rsat.LLDP.Tools~~~~0.0.1.0",
    "Rsat.NetworkController.Tools~~~~0.0.1.0",
    "Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0",
    "Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0",
    "Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0",
    "Rsat.ServerManager.Tools~~~~0.0.1.0",
    "Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0",
    "Rsat.StorageReplica.Tools~~~~0.0.1.0",
    "Rsat.SystemInsights.Management.Tools~~~~0.0.1.0",
    "Rsat.VolumeActivation.Tools~~~~0.0.1.0",
    "Rsat.WSUS.Tools~~~~0.0.1.0"
)

# Feature display names mapping
$FeatureDisplayNames = @{
    "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" = "Active Directory Domain Services and Lightweight Directory Services Tools"
    "Rsat.AzureStack.HCI.Management.Tools~~~~0.0.1.0" = "Azure Stack HCI Management Tools"
    "Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0" = "BitLocker Recovery Tools"
    "Rsat.CertificateServices.Tools~~~~0.0.1.0" = "Certificate Services Tools"
    "Rsat.DHCP.Tools~~~~0.0.1.0" = "DHCP Tools"
    "Rsat.Dns.Tools~~~~0.0.1.0" = "DNS Tools"
    "Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0" = "Failover Cluster Management Tools"
    "Rsat.FileServices.Tools~~~~0.0.1.0" = "File Services Tools"
    "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0" = "Group Policy Management Tools"
    "Rsat.IPAM.Client.Tools~~~~0.0.1.0" = "IP Address Management (IPAM) Client Tools"
    "Rsat.LLDP.Tools~~~~0.0.1.0" = "LLDP Tools"
    "Rsat.NetworkController.Tools~~~~0.0.1.0" = "Network Controller Tools"
    "Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0" = "Network Load Balancing Tools"
    "Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0" = "Remote Access Management Tools"
    "Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0" = "Remote Desktop Services Tools"
    "Rsat.ServerManager.Tools~~~~0.0.1.0" = "Server Manager Tools"
    "Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0" = "Storage Migration Service Management Tools"
    "Rsat.StorageReplica.Tools~~~~0.0.1.0" = "Storage Replica Tools"
    "Rsat.SystemInsights.Management.Tools~~~~0.0.1.0" = "System Insights Management Tools"
    "Rsat.VolumeActivation.Tools~~~~0.0.1.0" = "Volume Activation Tools"
    "Rsat.WSUS.Tools~~~~0.0.1.0" = "Windows Server Update Services Tools"
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
    
    # Check if it's Windows 11 (build 22000+)
    if ($os.Caption -match "Server") {
        throw "This script is for Windows 11 Workstation. Detected OS: $($os.Caption)"
    }
    
    # Check minimum version (Windows 11 = 10.0.22000)
    if ($version -lt [Version]"10.0.22000") {
        throw "This script requires Windows 11 (build 22000 or later). Detected version: $version (build $build)"
    }
    
    return @{
        Version = $version
        Build = $build
        Caption = $os.Caption
        IsWorkstation = $true
    }
}

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to get installed features
function Get-InstalledFeatures {
    $installed = @()
    foreach ($feature in $AvailableFeatures) {
        $capability = Get-WindowsCapability -Online -Name $feature -ErrorAction SilentlyContinue
        if ($capability -and $capability.State -eq "Installed") {
            $installed += $feature
        }
    }
    return $installed
}

# Function to select features interactively
function Select-Features {
    param([bool]$SkipPrompts, [string[]]$PreSelectedFeatures, [bool]$InstallAll)
    
    if ($InstallAll) {
        return $AvailableFeatures
    }
    
    if ($PreSelectedFeatures.Count -gt 0) {
        # Validate pre-selected features
        $validFeatures = @()
        foreach ($feature in $PreSelectedFeatures) {
            if ($AvailableFeatures -contains $feature) {
                $validFeatures += $feature
            } else {
                Write-ColorOutput "Warning: Unknown feature '$feature', skipping" "Yellow"
            }
        }
        if ($validFeatures.Count -gt 0) {
            return $validFeatures
        }
    }
    
    if ($SkipPrompts) {
        Write-ColorOutput "No features specified. Use -Features parameter or -InstallAll to install all features." "Yellow"
        return @()
    }
    
    Write-ColorOutput "==========================================" "Yellow"
    Write-ColorOutput "RSAT Features Selection" "Yellow"
    Write-ColorOutput "==========================================" "Yellow"
    Write-ColorOutput ""
    
    # Show installed features
    $installed = Get-InstalledFeatures
    if ($installed.Count -gt 0) {
        Write-ColorOutput "Already Installed Features:" "Green"
        foreach ($feature in $installed) {
            $displayName = $FeatureDisplayNames[$feature]
            Write-ColorOutput "  ✓ $displayName" "Gray"
        }
        Write-ColorOutput ""
    }
    
    # Show available features
    Write-ColorOutput "Available RSAT Features:" "Cyan"
    $index = 1
    $availableToInstall = @()
    foreach ($feature in $AvailableFeatures) {
        if ($installed -notcontains $feature) {
            $displayName = $FeatureDisplayNames[$feature]
            Write-ColorOutput "  [$index] $displayName" "White"
            $availableToInstall += $feature
            $index++
        }
    }
    Write-ColorOutput ""
    Write-ColorOutput "  [A] Install All" "White"
    Write-ColorOutput "  [Q] Quit" "White"
    Write-ColorOutput ""
    
    Write-ColorOutput "Enter feature numbers (comma-separated) or 'A' for all:" "Yellow"
    $selection = Read-Host
    
    if ($selection -eq "A" -or $selection -eq "a") {
        return $AvailableFeatures
    }
    
    if ($selection -eq "Q" -or $selection -eq "q") {
        return @()
    }
    
    $selectedFeatures = @()
    $numbers = $selection -split ','
    foreach ($num in $numbers) {
        $num = $num.Trim()
        $idx = [int]$num - 1
        if ($idx -ge 0 -and $idx -lt $availableToInstall.Count) {
            $selectedFeatures += $availableToInstall[$idx]
        }
    }
    
    return $selectedFeatures
}

# Function to install a feature
function Install-Feature {
    param([string]$FeatureName)
    
    $displayName = $FeatureDisplayNames[$FeatureName]
    Write-ColorOutput "Installing: $displayName" "Yellow"
    
    try {
        $result = Add-WindowsCapability -Online -Name $FeatureName -ErrorAction Stop
        
        if ($result.RestartNeeded) {
            Write-ColorOutput "  ✓ Installed (reboot may be required)" "Green"
            return @{ Success = $true; RestartNeeded = $true }
        } else {
            Write-ColorOutput "  ✓ Installed successfully" "Green"
            return @{ Success = $true; RestartNeeded = $false }
        }
    } catch {
        Write-ColorOutput "  ✗ Failed: $_" "Red"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

# Main installation process
try {
    Write-ColorOutput "==========================================" "Green"
    Write-ColorOutput "Windows Workstation Optional Features Installer" "Green"
    Write-ColorOutput "==========================================" "Green"
    Write-ColorOutput ""
    
    # Check if running as Administrator
    if (-not (Test-Administrator)) {
        throw "This script must be run as Administrator. Please restart PowerShell as Administrator."
    }
    
    # Detect OS version
    $osInfo = Get-OSVersion
    
    # Select features
    $featuresToInstall = Select-Features -SkipPrompts $SkipPrompts -PreSelectedFeatures $Features -InstallAll $InstallAll
    
    if ($featuresToInstall.Count -eq 0) {
        Write-ColorOutput "No features selected." "Yellow"
        return
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "Features to install: $($featuresToInstall.Count)" "Cyan"
    foreach ($feature in $featuresToInstall) {
        $displayName = $FeatureDisplayNames[$feature]
        Write-ColorOutput "  - $displayName" "Gray"
    }
    Write-ColorOutput ""
    
    if ($WTF) {
        Write-ColorOutput ""
        Write-ColorOutput "[WTF] Would install the following features:" "Yellow"
        foreach ($feature in $featuresToInstall) {
            $displayName = $FeatureDisplayNames[$feature]
            Write-ColorOutput "[WTF]   - $displayName ($feature)" "Gray"
        }
        Write-ColorOutput "[WTF] Would run: Add-WindowsCapability -Online -Name <feature>" "Gray"
        Write-ColorOutput "[WTF] Installation test completed - no changes made" "Green"
        return
    }
    
    # Confirm installation
    if (-not $SkipPrompts) {
        Write-ColorOutput "Proceed with installation? (Y/N)" "Yellow"
        $confirm = Read-Host
        if ($confirm -ne "Y" -and $confirm -ne "y") {
            Write-ColorOutput "Installation cancelled." "Yellow"
            return
        }
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "Installing features..." "Yellow"
    Write-ColorOutput "This may take several minutes depending on your internet connection..." "Gray"
    Write-ColorOutput ""
    
    $results = @()
    $restartNeeded = $false
    $successCount = 0
    $failCount = 0
    
    foreach ($feature in $featuresToInstall) {
        $result = Install-Feature -FeatureName $feature
        $results += @{
            Feature = $feature
            Result = $result
        }
        
        if ($result.Success) {
            $successCount++
            if ($result.RestartNeeded) {
                $restartNeeded = $true
            }
        } else {
            $failCount++
        }
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "==========================================" "Green"
    Write-ColorOutput "Installation Summary" "Green"
    Write-ColorOutput "==========================================" "Green"
    Write-ColorOutput "  Successfully installed: $successCount" "Green"
    if ($failCount -gt 0) {
        Write-ColorOutput "  Failed: $failCount" "Red"
    }
    Write-ColorOutput ""
    
    if ($restartNeeded) {
        Write-ColorOutput "Some features require a reboot to complete installation." "Yellow"
        Write-ColorOutput "Reboot now? (Y/N)" "Yellow"
        $restart = Read-Host
        if ($restart -eq "Y" -or $restart -eq "y") {
            Restart-Computer -Force
        }
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


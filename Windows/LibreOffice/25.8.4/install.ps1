#Requires -RunAsAdministrator

param(
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

# Configuration
$AppName = "LibreOffice"
$Version = "25.8.4"

# Detect architecture
$Arch = $env:PROCESSOR_ARCHITECTURE
if ($Arch -eq "ARM64") {
    $VendorUrl = "https://www.libreoffice.org/donate/dl/win-aarch64/25.8.4/en-US/LibreOffice_25.8.4_Win_aarch64.msi"
    $InstallerName = "LibreOffice_25.8.4_Win_aarch64.msi"
} else {
    $VendorUrl = "https://www.libreoffice.org/donate/dl/win-x86_64/25.8.4/en-US/LibreOffice_25.8.4_Win_x86-64.msi"
    $InstallerName = "LibreOffice_25.8.4_Win_x86-64.msi"
}

$TempDir = "$env:TEMP\libreoffice-install"

# Create temp directory (skip in WTF mode)
if (-not $WTF) {
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
}

# Function to download file with BITS fallback to Invoke-WebRequest
function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [bool]$TestOnly = $false
    )
    
    if ($TestOnly) {
        # In WTF mode, just verify the URL is accessible
        Write-Host "[WTF] Would download from: $Url" -ForegroundColor Cyan
        
        try {
            $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -ErrorAction Stop
            Write-Host "[WTF] URL is accessible (Status: $($response.StatusCode))" -ForegroundColor Green
            if ($response.Headers.'Content-Length') {
                Write-Host "[WTF] Content-Length: $($response.Headers.'Content-Length')" -ForegroundColor Gray
            }
            return $true
        }
        catch {
            Write-Host "[WTF] URL check failed: $_" -ForegroundColor Red
            return $false
        }
    }
    
    # Try Start-BitsTransfer first
    try {
        Write-Host "Attempting download with BITS..." -ForegroundColor Cyan
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
        Write-Host "Download completed using BITS" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "BITS transfer failed, falling back to Invoke-WebRequest..." -ForegroundColor Yellow
        Write-Host "BITS Error: $_" -ForegroundColor DarkYellow
        
        # Fallback to Invoke-WebRequest
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
            Write-Host "Download completed using Invoke-WebRequest" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "Invoke-WebRequest also failed: $_" -ForegroundColor Red
            return $false
        }
    }
}

# Function to verify file hash against manifest hash value or .sha256 file in GCS
function Verify-FileHashFromGCS {
    param(
        [string]$InstallerPath,
        [string]$AppName,
        [string]$Version,
        [string]$InstallerName
    )
    
    try {
        Write-Host "Verifying file hash..." -ForegroundColor Cyan
        $manifestPath = "Windows/$AppName/$Version/manifest.json"
        $verifyPath = "Windows/$AppName/$Version/$InstallerName"

        $expectedHash = $null
        try {
            $manifestUrl = "https://installrelay.com/api/manifest/$manifestPath"
            $manifestResponse = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -ErrorAction Stop
            $manifestContent = $manifestResponse.Content | ConvertFrom-Json
            
            foreach ($mediaItem in $manifestContent.installation.media) {
                if ($mediaItem.name -eq $InstallerName -and $mediaItem.hash.value) {
                    $expectedHash = $mediaItem.hash.value.ToLower()
                    Write-Host "Expected hash from manifest: $expectedHash" -ForegroundColor Gray
                    break
                }
            }
        }
        catch {
            Write-Host "Warning: Could not get hash from manifest: $_" -ForegroundColor Yellow
        }

        if (-not $expectedHash) {
            try {
                $sha256Url = "https://installrelay.com/api/artifacts/$verifyPath.sha256"
                $sha256Response = Invoke-WebRequest -Uri $sha256Url -UseBasicParsing -ErrorAction Stop
                $expectedHash = ($sha256Response.Content | Select-Object -First 1).Trim().ToLower()
                Write-Host "Expected hash from .sha256 file: $expectedHash" -ForegroundColor Gray
            }
            catch {
                Write-Host "Warning: Could not get hash from .sha256 file: $_" -ForegroundColor Yellow
            }
        }
        
        if (-not $expectedHash) {
            Write-Host "Warning: Could not retrieve expected hash from manifest or .sha256 file" -ForegroundColor Yellow
            Write-Host "Hash verification unavailable - proceeding with installation" -ForegroundColor Yellow
            return $true
        }

        $computedHash = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash.ToLower()
        Write-Host "Computed hash: $computedHash" -ForegroundColor Gray

        if ($computedHash -eq $expectedHash) {
            Write-Host "Hash verification passed" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Hash verification failed!" -ForegroundColor Red
            Write-Host "Expected: $expectedHash" -ForegroundColor Yellow
            Write-Host "Got:      $computedHash" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "Error during hash verification: $_" -ForegroundColor Red
        return $false
    }
}

try {
    if ($WTF) {
        Write-Host "[WTF] Would install: $AppName $Version" -ForegroundColor Green
    } else {
        Write-Host "Installing $AppName $Version..." -ForegroundColor Green
    }
    
    # Download installer directly from LibreOffice
    $InstallerPath = Join-Path $TempDir $InstallerName
    
    if ($WTF) {
        Write-Host "[WTF] Would download installer from LibreOffice..." -ForegroundColor Yellow
        Write-Host "[WTF] Installer URL: $VendorUrl" -ForegroundColor Gray
        Write-Host "[WTF] Installer name: $InstallerName" -ForegroundColor Gray
        Write-Host "[WTF] Architecture: $Arch" -ForegroundColor Gray
        
        if (-not (Download-File -Url $VendorUrl -Destination $InstallerPath -TestOnly $true)) {
            throw "Failed to verify installer URL"
        }
        
        Write-Host "[WTF] Would install using: msiexec.exe /i `"$InstallerPath`" /qn /norestart" -ForegroundColor Yellow
        Write-Host "[WTF] Installation test completed - no changes made" -ForegroundColor Green
    } else {
        Write-Host "Downloading installer from LibreOffice..." -ForegroundColor Yellow
        
        if (-not (Download-File -Url $VendorUrl -Destination $InstallerPath)) {
            throw "Failed to download installer"
        }
        
        Write-Host "Downloaded installer: $InstallerPath" -ForegroundColor Green
        
        # Verify file hash before installation
        if (-not (Verify-FileHashFromGCS -InstallerPath $InstallerPath -AppName $AppName -Version $Version -InstallerName $InstallerName)) {
            throw "Hash verification failed for $InstallerName"
        }
        
        # Install silently using msiexec
        Write-Host "Installing $AppName..." -ForegroundColor Yellow
        $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$InstallerPath`"", "/qn", "/norestart" -Wait -PassThru -NoNewWindow
        
        if ($Process.ExitCode -eq 0) {
            Write-Host "$AppName $Version installed successfully!" -ForegroundColor Green
        } else {
            throw "Installation failed with exit code $($Process.ExitCode)"
        }
    }
}
catch {
    Write-Host "Installation failed: $_" -ForegroundColor Red
    $LASTEXITCODE = 1
}
finally {
    # Cleanup (skip in WTF mode since we didn't create anything)
    if (-not $WTF) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[WTF] Would cleanup temp directory: $TempDir" -ForegroundColor Gray
    }
}



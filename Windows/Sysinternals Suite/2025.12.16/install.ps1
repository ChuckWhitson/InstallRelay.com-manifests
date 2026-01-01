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
$AppName = "Sysinternals Suite"
$Version = "2025.12.16"

# Installation directory variable
$InstallDir = "C:\Program Files\Sysinternals"

# PATH addition variable
$AddToPath = $true

# Detect architecture
$Arch = $env:PROCESSOR_ARCHITECTURE
if ($Arch -eq "ARM64") {
    $InstallerName = "SysinternalsSuite-ARM64.zip"
    $VendorUrl = "https://download.sysinternals.com/files/SysinternalsSuite-ARM64.zip"
} else {
    $InstallerName = "SysinternalsSuite.zip"
    $VendorUrl = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
}

$TempDir = "$env:TEMP\sysinternals-install"

# Create temp directory (skip in WTF mode)
if (-not $WTF) {
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
}

# Function to verify file hash against manifest hash value or .sha256 file in GCS
function Verify-FileHashFromGCS {
    param(
        [string]$FilePath,
        [string]$ManifestPath,  # e.g., "Windows/AppName/Version/manifest.json"
        [string]$InstallerName  # e.g., "Installer.exe"
    )
    
    try {
        # Compute hash of downloaded file
        Write-Host "Computing SHA256 hash of downloaded file..." -ForegroundColor Cyan
        $computedHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
        Write-Host "Computed hash: $computedHash" -ForegroundColor Gray
        
        # Try to get hash from manifest.json first
        $expectedHash = $null
        try {
            $manifestUrl = "https://installrelay.com/api/manifest/$ManifestPath"
            Write-Host "Fetching manifest to get expected hash..." -ForegroundColor Cyan
            $manifestResponse = Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -ErrorAction Stop
            $manifest = $manifestResponse.Content | ConvertFrom-Json
            
            # Find the media entry matching our installer
            foreach ($media in $manifest.installation.media) {
                if ($media.name -eq $InstallerName -and $media.hash.value) {
                    $expectedHash = $media.hash.value.ToLower()
                    Write-Host "Found hash in manifest: $expectedHash" -ForegroundColor Gray
                    break
                }
            }
        }
        catch {
            Write-Host "Could not get hash from manifest: $_" -ForegroundColor Yellow
        }
        
        # If not in manifest, try .sha256 file via API verify endpoint
        if (-not $expectedHash) {
            $sha256Path = $ManifestPath -replace "manifest\.json$", "$InstallerName"
            $verifyUrl = "https://installrelay.com/api/verify/$sha256Path"
            Write-Host "Fetching expected hash from .sha256 file via API..." -ForegroundColor Cyan
            
            try {
                $response = Invoke-WebRequest -Uri $verifyUrl -UseBasicParsing -ErrorAction Stop
                $verifyResult = $response.Content | ConvertFrom-Json
                
                if ($verifyResult.computed_hash) {
                    $expectedHash = $verifyResult.computed_hash.ToLower()
                } elseif ($verifyResult.stored_hash) {
                    $expectedHash = $verifyResult.stored_hash.ToLower()
                } else {
                    foreach ($result in $verifyResult.results) {
                        if ($result.source -eq "local" -and $result.details.expected_hash) {
                            $expectedHash = $result.details.expected_hash.ToLower()
                            break
                        }
                    }
                }
            }
            catch {
                Write-Host "Could not get hash from .sha256 file: $_" -ForegroundColor Yellow
            }
        }
        
        if (-not $expectedHash) {
            Write-Host "Warning: Could not retrieve expected hash from manifest or .sha256 file" -ForegroundColor Yellow
            Write-Host "Hash verification unavailable - proceeding with installation" -ForegroundColor Yellow
            return $true  # Allow installation to proceed if hash unavailable
        }
        
        Write-Host "Expected hash: $expectedHash" -ForegroundColor Gray
        
        # Compare hashes
        if ($computedHash -eq $expectedHash) {
            Write-Host "Hash verification PASSED" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Hash verification FAILED!" -ForegroundColor Red
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

# Function to add directory to PATH environment variable
function Add-ToPath {
    param(
        [string]$PathToAdd,
        [bool]$TestOnly = $false
    )
    
    if ($TestOnly) {
        Write-Host "[WTF] Would add to PATH: $PathToAdd" -ForegroundColor Cyan
        return $true
    }
    
    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        
        # Check if already in PATH
        if ($currentPath -split ';' -contains $PathToAdd) {
            Write-Host "Directory already in PATH: $PathToAdd" -ForegroundColor Yellow
            return $true
        }
        
        # Add to PATH
        $newPath = $currentPath + ";" + $PathToAdd
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        
        # Also update current session PATH
        $env:Path += ";$PathToAdd"
        
        Write-Host "Added to PATH: $PathToAdd" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to add to PATH: $_" -ForegroundColor Red
        return $false
    }
}

try {
    if ($WTF) {
        Write-Host "[WTF] Would install: $AppName $Version" -ForegroundColor Green
    } else {
        Write-Host "Installing $AppName $Version..." -ForegroundColor Green
    }
    Write-Host "Detected architecture: $Arch" -ForegroundColor Cyan
    Write-Host "Installation directory: $InstallDir" -ForegroundColor Cyan
    Write-Host "Add to PATH: $AddToPath" -ForegroundColor Cyan
    
    # Download ZIP file
    $ZipPath = Join-Path $TempDir $InstallerName
    
    if ($WTF) {
        Write-Host "[WTF] Would download ZIP from download.sysinternals.com..." -ForegroundColor Yellow
        Write-Host "[WTF] ZIP URL: $VendorUrl" -ForegroundColor Gray
        Write-Host "[WTF] ZIP name: $InstallerName" -ForegroundColor Gray
        
        if (-not (Download-File -Url $VendorUrl -Destination $ZipPath -TestOnly $true)) {
            throw "Failed to verify ZIP URL"
        }
        
        Write-Host "[WTF] Would extract ZIP to: $InstallDir" -ForegroundColor Yellow
        if ($AddToPath) {
            Write-Host "[WTF] Would add to PATH: $InstallDir" -ForegroundColor Yellow
        }
        Write-Host "[WTF] Installation test completed - no changes made" -ForegroundColor Green
    } else {
        Write-Host "Downloading ZIP from download.sysinternals.com..." -ForegroundColor Yellow
        
        if (-not (Download-File -Url $VendorUrl -Destination $ZipPath)) {
            throw "Failed to download ZIP file"
        }
        
        # Verify file hash against manifest hash value or .sha256 file in GCS
        $manifestPath = "Windows/Sysinternals Suite/2025.12.16/manifest.json"
        if (-not (Verify-FileHashFromGCS -FilePath $ZipPath -ManifestPath $manifestPath -InstallerName $InstallerName)) {
            throw "Hash verification failed - downloaded file does not match expected hash"
        }
        
        # Create installation directory
        Write-Host "Creating installation directory: $InstallDir" -ForegroundColor Yellow
        if (-not (Test-Path $InstallDir)) {
            New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        }
        
        # Extract ZIP file
        Write-Host "Extracting ZIP file..." -ForegroundColor Yellow
        Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
        
        Write-Host "Extraction completed successfully!" -ForegroundColor Green
        
        # Add to PATH if requested
        if ($AddToPath) {
            Write-Host "Adding installation directory to PATH..." -ForegroundColor Yellow
            Add-ToPath -PathToAdd $InstallDir
        }
        
        Write-Host "Installation completed successfully!" -ForegroundColor Green
        Write-Host "Sysinternals Suite has been installed to: $InstallDir" -ForegroundColor Cyan
        if ($AddToPath) {
            Write-Host "Installation directory has been added to PATH" -ForegroundColor Cyan
            Write-Host "Note: You may need to restart your terminal or log out/in for PATH changes to take effect" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "Installation failed: $_" -ForegroundColor Red
    # Don't exit - allow script to continue so multiple installations can run
    # Set error code that can be checked by caller if needed
    $LASTEXITCODE = 1
}
finally {
    # Cleanup (skip in WTF mode since we didn't create anything)
    if (-not $WTF) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[WTF] Would cleanup temp directory: $TempDir" -ForegroundColor Gray
    }
    # Script ends naturally - no exit command, console stays open for multiple installations
}


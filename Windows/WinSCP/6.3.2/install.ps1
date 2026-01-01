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
$AppName = "WinSCP"
$Version = "6.5.5"
# WinSCP download URLs - try direct download first, fallback to download page
$DirectDownloadUrl = "https://winscp.net/eng/downloads/WinSCP-6.5.5-Setup.exe"
$DownloadPageUrl = "https://winscp.net/eng/download.php"
$InstallerName = "WinSCP-6.5.5-Setup.exe"
$TempDir = "$env:TEMP\winscp-install"

# Function to resolve WinSCP download URL
function Resolve-WinSCPDownloadUrl {
    param([string]$DownloadPageUrl)
    
    
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

    
    try {
        Write-Host "Fetching download page..." -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $DownloadPageUrl -UseBasicParsing -ErrorAction Stop
        
        # Check if we got redirected to an .exe file
        $redirectUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
        if ($redirectUrl -like "*.exe*") {
            Write-Host "Found redirect to: $redirectUrl" -ForegroundColor Gray
            return $redirectUrl
        }
        
        # Parse HTML for download links
        $content = $response.Content
        
        # Look for direct download links
        $patterns = @(
            'href="([^"]*WinSCP[^"]*Setup[^"]*\.exe[^"]*)"',
            'href="([^"]*downloads[^"]*WinSCP[^"]*\.exe[^"]*)"',
            'href="([^"]*\.exe)"',
            'download.*href="([^"]*\.exe)"'
        )
        
        foreach ($pattern in $patterns) {
            if ($content -match $pattern) {
                $foundUrl = $matches[1]
                if (-not $foundUrl.StartsWith("http")) {
                    if ($foundUrl.StartsWith("/")) {
                        $foundUrl = "https://winscp.net" + $foundUrl
                    } else {
                        $foundUrl = "https://winscp.net/" + $foundUrl
                    }
                }
                if ($foundUrl -like "*WinSCP*" -and $foundUrl -like "*.exe") {
                    Write-Host "Found download link: $foundUrl" -ForegroundColor Gray
                    return $foundUrl
                }
            }
        }
        
        # Fallback: try common URL patterns
        $fallbackUrls = @(
            "https://winscp.net/eng/downloads/WinSCP-Setup.exe",
            "https://winscp.net/download/WinSCP-Setup.exe"
        )
        
        foreach ($fallback in $fallbackUrls) {
            try {
                $testResponse = Invoke-WebRequest -Uri $fallback -Method Head -UseBasicParsing -ErrorAction Stop
                Write-Host "Using fallback URL: $fallback" -ForegroundColor Gray
                return $fallback
            }
            catch {
                continue
            }
        }
        
        throw "Could not resolve download URL"
    }
    catch {
        Write-Host "Error resolving download URL: $_" -ForegroundColor Red
        throw
    }
}

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
    
    # Use URL as-is (redirect resolution happens before calling Download-File)
    $downloadUrl = $Url
    
    if ($TestOnly) {
        # In WTF mode, just verify the URL is accessible
        Write-Host "[WTF] Would download from: $downloadUrl" -ForegroundColor Cyan
        try {
            $response = Invoke-WebRequest -Uri $downloadUrl -Method Head -UseBasicParsing -ErrorAction Stop
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
        Start-BitsTransfer -Source $downloadUrl -Destination $Destination -ErrorAction Stop
        Write-Host "Download completed using BITS" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "BITS transfer failed, falling back to Invoke-WebRequest..." -ForegroundColor Yellow
        Write-Host "BITS Error: $_" -ForegroundColor DarkYellow
        
        # Fallback to Invoke-WebRequest
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $Destination -UseBasicParsing -ErrorAction Stop
            Write-Host "Download completed using Invoke-WebRequest" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "Invoke-WebRequest also failed: $_" -ForegroundColor Red
            return $false
        }
    }
}

try {
    if ($WTF) {
        Write-Host "[WTF] Would install: $AppName $Version" -ForegroundColor Green
    } else {
        Write-Host "Installing $AppName $Version..." -ForegroundColor Green
    }
    
    # Download installer directly from WinSCP website
    $InstallerPath = Join-Path $TempDir $InstallerName
    
    # Try direct download URL first, then resolve from download page if needed
    $actualDownloadUrl = $DirectDownloadUrl
    $urlVerified = $false
    
    # Test if direct URL works
    try {
        Write-Host "Verifying direct download URL..." -ForegroundColor Gray
        $testResponse = Invoke-WebRequest -Uri $DirectDownloadUrl -Method Head -UseBasicParsing -ErrorAction Stop
        if ($testResponse.StatusCode -eq 200) {
            Write-Host "Direct download URL verified" -ForegroundColor Gray
            $urlVerified = $true
        }
    }
    catch {
        Write-Host "Direct URL not available, resolving from download page..." -ForegroundColor Yellow
    }
    
    # If direct URL doesn't work, try to resolve from download page
    if (-not $urlVerified) {
        try {
            $actualDownloadUrl = Resolve-WinSCPDownloadUrl -DownloadPageUrl $DownloadPageUrl
            $InstallerName = [System.IO.Path]::GetFileName($actualDownloadUrl)
            $InstallerPath = Join-Path $TempDir $InstallerName
            Write-Host "Resolved download URL: $actualDownloadUrl" -ForegroundColor Gray
        }
        catch {
            Write-Host "Warning: Could not resolve download URL: $_" -ForegroundColor Yellow
            Write-Host "Will attempt direct download URL anyway..." -ForegroundColor Yellow
        }
    }
    
    if ($WTF) {
        Write-Host "[WTF] Would download installer from WinSCP website..." -ForegroundColor Yellow
        Write-Host "[WTF] Installer URL: $actualDownloadUrl" -ForegroundColor Gray
        Write-Host "[WTF] Installer name: $InstallerName" -ForegroundColor Gray
        
        if (-not (Download-File -Url $actualDownloadUrl -Destination $InstallerPath -TestOnly $true)) {
            throw "Failed to verify installer URL"
        }
        
        Write-Host "[WTF] Would install using: $InstallerName /SILENT /NORESTART" -ForegroundColor Yellow
        Write-Host "[WTF] Installation test completed - no changes made" -ForegroundColor Green
    } else {
        Write-Host "Downloading installer from WinSCP website..." -ForegroundColor Yellow
        
                if (-not (Download-File -Url $VendorUrl -Destination $InstallerPath)) {
            throw "Failed to download installer"
        }
        
        # Verify file hash against manifest hash value or .sha256 file in GCS
        $manifestPath = "Windows/WinSCP/6.3.2/manifest.json"
        if (-not (Verify-FileHashFromGCS -FilePath $InstallerPath -ManifestPath $manifestPath -InstallerName $InstallerName)) {
            throw "Hash verification failed - downloaded file does not match expected hash"
        }
        
        # Run installer silently
        # Run installer silently
        Write-Host "Running installer..." -ForegroundColor Yellow
        $Process = Start-Process -FilePath $InstallerPath -ArgumentList "/SILENT", "/NORESTART" -Wait -PassThru -NoNewWindow
        if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq $null) {
            Write-Host "Installation completed successfully!" -ForegroundColor Green
        } else {
            throw "Installation failed with exit code $($Process.ExitCode)"
        }
    }
}
catch {
    Write-Host "Installation failed: $_" -ForegroundColor Red
    # Don't exit - allow script to continue so multiple installations can run
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


# InstallRelay Manifest Templates

This directory contains templates and documentation for creating new application manifests for InstallRelay.com.

## Directory Structure

```
~Template/
├── README.md (this file)
├── PR_TEMPLATE.md (Pull Request template)
├── Windows/
│   ├── install.ps1 (PowerShell installation script template)
│   └── manifest.json (Windows manifest template)
├── MacOS/
│   ├── install.sh (Shell installation script template)
│   └── manifest.json (macOS manifest template)
└── Linux/
    ├── install.sh (Shell installation script template)
    └── manifest.json (Linux manifest template)
```

## Quick Start

1. **Copy the template** for your target OS:
   ```bash
   # Windows
   cp -r Windows/ ~/NewApp/1.0.0/
   
   # macOS
   cp -r MacOS/ ~/NewApp/1.0.0/
   
   # Linux
   cp -r Linux/ ~/NewApp/1.0.0/
   ```

2. **Update the install script** (`install.ps1` or `install.sh`):
   - Replace all `TODO` comments with actual values
   - Update application name and version
   - Update installer URLs for all architectures
   - Update silent install arguments
   - Update manifest path in hash verification function

3. **Update the manifest** (`manifest.json`):
   - Update all application metadata
   - Update download URLs for all architectures
   - Add SHA256 hash values (or they will be generated)
   - Update API endpoint paths (use capitalized OS names: `Windows`, `MacOS`, `Linux`)

4. **Test WTF mode**:
   ```bash
   # Windows
   powershell -ExecutionPolicy Bypass -File install.ps1 -WTF
   
   # macOS/Linux
   ./install.sh -WTF
   ```

5. **Test actual installation**:
   ```bash
   # Windows (as Administrator)
   powershell -ExecutionPolicy Bypass -File install.ps1
   
   # macOS/Linux (with sudo)
   sudo ./install.sh
   ```

6. **Create a Pull Request** using the `PR_TEMPLATE.md` as a guide

## Template Requirements

All installation scripts MUST include:

1. **WTF Mode Support**
   - Accept `-WTF` or `--WTF` parameter
   - Check `INSTALLRELAY_WTF` environment variable
   - Display `[WTF]` prefix for all test operations
   - Never make actual system changes in WTF mode

2. **Hash Verification**
   - Call `Verify-FileHashFromGCS` function after download (Windows)
   - Verify hash against manifest.json or .sha256 files
   - Fail installation if hash mismatch

3. **Architecture Detection**
   - Detect system architecture (x64, arm64, aarch64, etc.)
   - Download correct installer for detected architecture
   - Support all architectures listed in manifest.json

4. **Error Handling**
   - Use `set -e` in shell scripts (bash)
   - Use `$ErrorActionPreference = "Stop"` in PowerShell
   - Proper try/catch or trap blocks
   - Meaningful error messages

5. **Standard Structure**
   - Configuration section at top
   - Helper functions (Download-File, Verify-FileHashFromGCS)
   - Main installation logic
   - Cleanup in finally/trap block

## Manifest Requirements

All manifest.json files MUST include:

1. **Required Fields**
   - `name`: Application name
   - `version`: Version number (semantic versioning preferred)
   - `description`: Brief description
   - `vendor`: Vendor name
   - `license`: License type
   - `homepage`: Application homepage URL

2. **OS Configuration**
   - `platform`: `windows`, `macos`, or `linux` (lowercase)
   - `minOSVersion`: Minimum OS version required
   - `supportedArchitectures`: Array of supported architectures

3. **Installation Media**
   - At least one media entry per architecture
   - Direct download URLs (not redirect pages)
   - SHA256 hash values (in `hash.value` or via `.sha256` files)
   - `vendor_url`: Original vendor download URL

4. **API Endpoints**
   - Use capitalized OS folder names: `Windows`, `MacOS`, `Linux`
   - Format: `/api/manifest/{OS}/{AppName}/{Version}/manifest.json`
   - Format: `/api/apps/{OS}/{AppName}/{Version}/install.{ps1|sh}`

## Common Patterns

### Windows Silent Install Arguments

- **NSIS Installers**: `/S` or `/SILENT` or `/VERYSILENT /ALLUSERS /NORESTART`
- **MSI Installers**: `msiexec.exe /i "installer.msi" /quiet /norestart`
- **Inno Setup**: `/VERYSILENT /ALLUSERS /NORESTART`
- **Custom**: Check vendor documentation

### macOS Installation

- **DMG**: Mount, copy .app to /Applications, unmount
- **PKG**: Use `installer` command with `-pkg` flag
- **ZIP/TAR**: Extract and copy to appropriate location

### Linux Installation

- **Try package manager first**: `apt-get`, `dnf`, `yum`
- **Fallback to direct download**: `.deb`, `.rpm`, `.tar.gz`, `.tar.xz`
- **Extract to `/opt`**: Create symlinks in `/usr/local/bin` if needed

## Testing Checklist

Before submitting a PR:

- [ ] WTF mode works: `./install.sh -WTF` or `install.ps1 -WTF`
- [ ] Hash verification works
- [ ] Silent installation works
- [ ] Architecture detection works for all supported architectures
- [ ] Error handling works (test with invalid URLs, etc.)
- [ ] Cleanup works (temp files removed)
- [ ] Manifest.json is valid JSON
- [ ] All URLs are direct download links
- [ ] API endpoint paths use capitalized OS names

## Resources

- [Manifest Schema](../schemas/manifest-schema.json)
- [API Reference](../../docs/API_REFERENCE.md)
- [WTF Mode Documentation](../../docs/WTF_MODE_VALIDATION.md)

## Support

For questions or issues:
- Open an issue in the repository
- Contact: admin@installrelay.com

© 2025 InstallRelay. All Rights Reserved.


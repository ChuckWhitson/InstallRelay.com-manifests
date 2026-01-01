# Application Manifest Pull Request

## Checklist

Before submitting this PR, please ensure:

- [ ] All TODO comments in the install script have been completed
- [ ] The install script follows the template structure from `~Template/install.ps1` or `~Template/install.sh`
- [ ] WTF mode (`-WTF` or `--WTF`) has been tested and works correctly
- [ ] Hash verification is implemented and tested
- [ ] Silent installation parameters are correct for the application
- [ ] Architecture detection works for all supported architectures
- [ ] The manifest.json file is valid JSON and follows the template
- [ ] All URLs in manifest.json are direct download links (not redirect pages)
- [ ] SHA256 hash values are included in manifest.json or `.sha256` files will be generated
- [ ] API endpoint paths use capitalized OS folder names (`Windows`, `MacOS`, `Linux`)
- [ ] The application name matches exactly between manifest.json and install script
- [ ] Version number matches exactly between manifest.json and install script

## Application Information

**Application Name:** [Application Name]
**Version:** [Version Number]
**OS:** [Windows/MacOS/Linux]
**Architectures Supported:** [x64, arm64, etc.]

## Changes Made

### Install Script (`install.ps1` or `install.sh`)
- [ ] Copied from `~Template/` folder
- [ ] Updated application name and version
- [ ] Updated installer URLs for all architectures
- [ ] Updated installer file names
- [ ] Updated silent install arguments
- [ ] Updated manifest path in hash verification function
- [ ] Tested WTF mode: `[command to test]`
- [ ] Tested actual installation: `[command to test]`

### Manifest (`manifest.json`)
- [ ] Copied from `~Template/` folder
- [ ] Updated all application metadata
- [ ] Updated download URLs for all architectures
- [ ] Added SHA256 hash values (or will be generated)
- [ ] Updated API endpoint paths
- [ ] Validated JSON syntax

## Testing

### WTF Mode Testing
```bash
# Windows
powershell -ExecutionPolicy Bypass -File install.ps1 -WTF

# MacOS/Linux
./install.sh -WTF
```

**Result:** [PASS/FAIL - Describe any issues]

### Hash Verification Testing
- [ ] Hash verification function is called after download
- [ ] Hash verification works with manifest.json hash values
- [ ] Hash verification works with .sha256 files (if applicable)
- [ ] Hash mismatch correctly fails installation

**Result:** [PASS/FAIL - Describe any issues]

### Installation Testing
```bash
# Windows
powershell -ExecutionPolicy Bypass -File install.ps1

# MacOS/Linux
sudo ./install.sh
```

**Result:** [PASS/FAIL - Describe any issues]

### Architecture Detection Testing
- [ ] x64 architecture detected correctly
- [ ] arm64/aarch64 architecture detected correctly (if supported)
- [ ] Correct installer downloaded for each architecture

**Result:** [PASS/FAIL - Describe any issues]

## Silent Install Parameters

**Windows:** `/S` or `/VERYSILENT` or `msiexec.exe /i ... /quiet` etc.
**MacOS:** [Usually not silent, but describe process]
**Linux:** [Package manager or extraction process]

**Source:** [Link to vendor documentation or tested parameters]

## Download URLs

**x64:** [URL]
**arm64/aarch64:** [URL if applicable]

**Verification:** [How you verified these URLs are direct download links]

## Hash Values

**Source:** [Where hash values came from - vendor page, computed locally, etc.]

**x64 Hash:** [SHA256 hash]
**arm64 Hash:** [SHA256 hash if applicable]

## Additional Notes

[Any additional information, special considerations, or known issues]

## Related Issues

[Link to related GitHub issues if any]

---

**Reviewer Notes:**
- Please verify all URLs are accessible
- Please verify hash values match downloaded files
- Please test WTF mode
- Please verify silent install parameters are correct

© 2025 InstallRelay. All Rights Reserved.


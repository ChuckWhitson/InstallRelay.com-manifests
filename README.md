# InstallRelay.com Manifests

This repository contains all application manifests, installation scripts, and configuration files for InstallRelay.com.

## Structure

```
manifests/
├── Windows/
│   ├── {Application-Name}/
│   │   ├── {version}/
│   │   │   ├── manifest.json
│   │   │   ├── install.ps1
│   │   │   └── configs/ (optional)
│   │   │       └── ...
│   │   └── ...
│   └── ...
├── MacOS/
│   └── ... (same structure)
└── Linux/
    └── ... (same structure)
```

## OS Folder Naming

OS folders are capitalized to match the GCP bucket structure:
- `Windows/` (not `windows/`)
- `MacOS/` (not `macos/` or `macOS/`)
- `Linux/` (not `linux/`)

## Manifest Format

Each application version has:
- `manifest.json` - Application metadata, download URLs, installation parameters
- `install.ps1` (Windows) or `install.sh` (macOS/Linux) - Installation script
- Optional `configs/` directory - Configuration files

## Workflow

1. **Review**: All changes to manifests are reviewed via pull requests
2. **Merge**: Once approved, changes are merged to the main branch
3. **Deploy**: GitHub Actions automatically syncs changes to GCS bucket

## Contributing

1. Create a branch for your changes
2. Make your changes to manifests/scripts
3. Submit a pull request for review
4. Once approved, changes will be automatically deployed

## CI/CD Pipeline

Changes pushed to the `main` branch automatically trigger a GitHub Actions workflow that:
1. Validates all manifest.json files
2. Syncs changes to the GCS bucket (`gs://installrelay/manifests/`)
3. Updates the InstallRelay.com API

## Local Development

To test changes locally before submitting:

```bash
# Validate a manifest
python3 -m json.tool manifests/Windows/7-Zip/25.01/manifest.json

# Test installation script (Windows)
powershell -ExecutionPolicy Bypass -File manifests/Windows/7-Zip/25.01/install.ps1 -WTF
```

## Notes

- This repository is currently **private** but will be made public in the future
- All manifests must follow the [manifest schema](../schemas/manifest-schema.json)
- Installation scripts must support WTF mode for testing (`-WTF` or `--WTF` flag)

© 2025 InstallRelay. All Rights Reserved.


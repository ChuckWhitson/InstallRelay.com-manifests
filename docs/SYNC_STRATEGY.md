# Manifest Sync Strategy: GitHub to GCP

This document describes the strategy for syncing manifests from the GitHub repository to Google Cloud Storage (GCS).

## Overview

We use a **push-based approach** where GitHub Actions automatically syncs manifests to GCS whenever changes are pushed to the repository. This is complemented by scheduled daily syncs and manual triggers.

## Sync Methods

### 1. Automatic Push-Based Sync (Primary)

**Workflow:** `.github/workflows/sync-to-gcs.yml`

**Triggers:**
- ✅ **Push to main branch** - Automatically syncs when manifests are updated
- ✅ **Manual trigger** - Can be triggered manually from GitHub Actions UI
- ✅ **Daily scheduled sync** - Runs daily at 2:00 AM UTC

**How it works:**
1. Developer pushes changes to GitHub
2. GitHub Actions workflow validates all JSON files
3. If validation passes, syncs all files to GCS using `gsutil rsync`
4. Verifies sync completed successfully

**Advantages:**
- Immediate sync when changes are made
- Validates before syncing
- Uses Workload Identity Federation (secure, no keys)
- No additional infrastructure needed

### 2. Scheduled Daily Sync (Backup)

**Workflow:** `.github/workflows/sync-to-gcs.yml` (same workflow, scheduled trigger)

**Schedule:** Daily at 2:00 AM UTC

**Purpose:**
- Ensures GCS is always up-to-date even if push-based sync fails
- Catches any missed updates
- Provides redundancy

### 3. Manual Trigger

**Workflow:** `.github/workflows/sync-to-gcs.yml`

**How to trigger:**
1. Go to GitHub repository → Actions tab
2. Select "Sync Manifests to GCS" workflow
3. Click "Run workflow"
4. Optionally enable "Force sync" checkbox
5. Click "Run workflow" button

**Use cases:**
- Testing sync process
- Recovering from sync failures
- Force syncing after manual GCS changes

## Alternative: Pull-Based Sync (Optional)

**Workflow:** `.github/workflows/sync-from-github.yml`

This workflow can be used if you prefer to trigger syncs from the GCP side or want a backup method.

**Triggers:**
- Manual trigger (can specify branch)
- Scheduled daily at 3:00 AM UTC

**Note:** This workflow requires updating `GITHUB_OWNER` in the workflow file.

## Architecture

```
┌─────────────────┐
│   GitHub Repo   │
│  (Source of     │
│   Truth)        │
└────────┬────────┘
         │
         │ Push / Schedule / Manual
         ▼
┌─────────────────┐
│ GitHub Actions  │
│  (Validation &  │
│   Sync Logic)   │
└────────┬────────┘
         │
         │ gsutil rsync
         ▼
┌─────────────────┐
│   GCS Bucket    │
│  (installrelay) │
│  manifests/     │
└────────┬────────┘
         │
         │ Serves via API
         ▼
┌─────────────────┐
│ InstallRelay.com│
│     API Server  │
└─────────────────┘
```

## Security

### Workload Identity Federation

We use **Workload Identity Federation** instead of service account keys:

1. **No keys stored** - More secure than service account keys
2. **Short-lived tokens** - Tokens expire automatically
3. **Repository-scoped** - Only works for specific repository
4. **Auditable** - All actions logged in GCP

### Required Secrets

Configure these in GitHub repository settings:

- `WIF_PROVIDER`: Workload Identity Provider resource name
- `WIF_SERVICE_ACCOUNT`: Service account email

See `SETUP.md` for detailed setup instructions.

## Monitoring

### GitHub Actions

- View workflow runs in GitHub → Actions tab
- Check logs for sync status
- Set up notifications for workflow failures

### GCS Monitoring

- Monitor bucket access logs
- Set up alerts for unusual activity
- Track sync frequency and success rate

## Troubleshooting

### Sync Fails

1. **Check GitHub Actions logs** - Look for error messages
2. **Verify Workload Identity setup** - Ensure secrets are correct
3. **Check GCS permissions** - Service account needs `storage.objectAdmin`
4. **Validate JSON files** - Ensure all manifests are valid JSON

### Files Not Appearing in GCS

1. **Check sync logs** - Verify files were actually synced
2. **Verify paths** - Ensure files match expected structure
3. **Check GCS console** - Manually verify files exist
4. **Force sync** - Use manual trigger to force re-sync

### Validation Errors

1. **Fix JSON syntax** - Use `python3 -m json.tool` to validate
2. **Check file encoding** - Ensure UTF-8 encoding
3. **Review manifest schema** - Ensure follows expected structure

## Best Practices

1. **Always validate locally** before pushing:
   ```bash
   python3 -m json.tool manifest.json
   ```

2. **Test WTF mode** before committing:
   ```bash
   ./install.ps1 -WTF
   ```

3. **Use PRs for review** - Don't push directly to main
4. **Monitor sync status** - Check Actions tab regularly
5. **Keep manifests organized** - Follow folder structure conventions

## Future Enhancements

- [ ] Add Cloud Function as backup sync method
- [ ] Implement sync status dashboard
- [ ] Add webhook notifications for sync completion
- [ ] Create sync health check endpoint
- [ ] Add rollback capability for failed syncs

## Related Documentation

- `SETUP.md` - Initial setup instructions
- `README.md` - Repository documentation
- `PR_TEMPLATE.md` - Pull request template

© 2025 InstallRelay. All Rights Reserved.


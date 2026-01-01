# Setup Instructions for InstallRelay.com-manifests Repository

This document explains how to set up the separate GitHub repository for manifests.

## Prerequisites

1. GitHub account with access to create private repositories
2. Google Cloud Platform account with access to the `installrelay` bucket
3. GitHub Actions enabled for the repository

## Step 1: Create the GitHub Repository

1. Go to GitHub and create a new **private** repository named `InstallRelay.com-manifests`
2. Do NOT initialize with a README, .gitignore, or license (we'll add these)

## Step 2: Initialize the Repository Locally

```bash
# Navigate to the manifests directory
cd /path/to/InstallRelay.com/manifests

# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Add all manifests"

# Add remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/InstallRelay.com-manifests.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 3: Configure GitHub Actions Secrets

For the GitHub Actions workflow to sync to GCS, you need to configure Workload Identity Federation:

1. Go to your repository settings → Secrets and variables → Actions
2. Add the following secrets:
   - `WIF_PROVIDER`: Workload Identity Provider (format: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID`)
   - `WIF_SERVICE_ACCOUNT`: Service account email (format: `SERVICE_ACCOUNT@PROJECT_ID.iam.gserviceaccount.com`)

### Setting up Workload Identity Federation

If you haven't set up Workload Identity Federation yet:

```bash
# Set variables
export PROJECT_ID="your-gcp-project-id"
export WIF_POOL="github-actions-pool"
export WIF_PROVIDER="github-provider"
export SERVICE_ACCOUNT="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
export REPO="YOUR_USERNAME/InstallRelay.com-manifests"

# Create Workload Identity Pool
gcloud iam workload-identity-pools create "${WIF_POOL}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc "${WIF_PROVIDER}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WIF_POOL}" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='${REPO}'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Create Service Account
gcloud iam service-accounts create github-actions \
  --project="${PROJECT_ID}" \
  --display-name="GitHub Actions Service Account"

# Grant permissions to Service Account
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/storage.objectAdmin"

# Allow GitHub to impersonate the Service Account
gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/${WIF_POOL}/*"

# Get the Workload Identity Provider resource name
gcloud iam workload-identity-pools providers describe "${WIF_PROVIDER}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WIF_POOL}" \
  --format="value(name)"
```

Copy the output and use it as `WIF_PROVIDER` in GitHub Secrets.

## Step 4: Test the Workflow

1. Make a small change to a manifest file
2. Commit and push:
   ```bash
   git add .
   git commit -m "Test: Update manifest"
   git push
   ```
3. Go to the Actions tab in GitHub to see the workflow run
4. Verify that files are synced to GCS:
   ```bash
   gsutil ls -r gs://installrelay/manifests/ | head -20
   ```

## Step 5: Update Main Repository

After setting up the separate manifests repository:

1. Remove the `manifests/` folder from the main InstallRelay.com repository (or add it to .gitignore)
2. Update any documentation that references the manifests folder location
3. The API server will continue to read from GCS, so no code changes are needed

## Troubleshooting

### Workflow fails with authentication error
- Verify that `WIF_PROVIDER` and `WIF_SERVICE_ACCOUNT` secrets are set correctly
- Check that the service account has `roles/storage.objectAdmin` permission
- Ensure the Workload Identity Provider is correctly configured

### Files not syncing
- Check the workflow logs in GitHub Actions
- Verify the GCS bucket name is correct (`installrelay`)
- Ensure the service account has write permissions

### JSON validation fails
- Run `python3 -m json.tool <file>` locally to find syntax errors
- Check that all JSON files follow the manifest schema

## Future Enhancements

- Add manifest schema validation using JSON Schema
- Add automated testing for installation scripts
- Add preview/deployment environments
- Make repository public when ready

© 2025 InstallRelay. All Rights Reserved.


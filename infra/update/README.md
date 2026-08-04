# Update deployment

This folder contains the Bicep entrypoint used to redeploy the Acmebot package into an existing Function App.

## What it does

- Targets an existing Azure Function App by name and discovers its resource group automatically
- Downloads the Acmebot release ZIP from GitHub
- Uses the `Microsoft.Web/sites/extensions` OneDeploy path to push the package
- Keeps the platform resources created by `infra/create` intact

## Files

- `Invoke-AzDeployment.ps1` — deployment wrapper for the update flow
- `main.bicep` — deployment template for the update flow
- `param.main.bicepparam` — example parameter file for local or scripted deployment

## Versioning

Use `acmebotReleaseTag` in `param.main.bicepparam` to choose the package version:

- `latest` — deploy the newest GitHub release asset
- `5.0.0` or `v5.0.0` — deploy a pinned release

The template normalizes the value and constructs the correct release URL automatically.

## Example

```bicep
using './main.bicep'

param functionAppName = 'func-bwc-kvacme-dev-weu'
param acmebotReleaseTag = 'latest'
```

The wrapper script accepts the same `functionAppName` plus the subscription ID, and it can use the Function App's own location if you do not pass `location`.

## Notes

- The Function App must already exist before this deployment runs.
- The OneDeploy extension is intentionally wrapped in `infra/modules/app/site/extension/main.bicep` for reuse.
- This update flow is package-only; it does not recreate the base infrastructure.

---

### Last updated

2026-08-04

# Create deployment

This folder contains the Bicep entrypoint used to deploy the full Acmebot platform and supporting Azure resources.

## What it does

- Creates the resource group, managed identities, storage, Key Vault, observability, and Function App
- Deploys Microsoft Entra resources through the Microsoft Graph Bicep extension
- Deploys the Acmebot package into the Function App using OneDeploy
- Supports optional virtual network and private DNS creation

## Files

- `main.bicep` — full platform deployment template
- `param.main.bicepparam` — example parameter file for the create flow
- `Invoke-AzDeployment.ps1` — deployment wrapper for validation, what-if, and execution

## Versioning

Use `acmebotReleaseTag` in `param.main.bicepparam` to choose the Acmebot release:

- `latest` — deploy the newest GitHub release asset
- `5.0.0` or `v5.0.0` — deploy a pinned release

The template normalizes the tag and builds the correct package URL automatically.

## Notes

- This is the initial deployment path for the environment.
- The Key Vault uses Access Policies by design to support the Application Gateway certificate scenario.
- The `dependsOn` helpers are intentionally retained as visual guidance for engineers.
- When GitHub Actions federation is enabled, opt this repository into GitHub's immutable OIDC subject format; the setting is outside Bicep and must be configured in GitHub repository settings.

---

### Last updated

2026-08-04

# Azure Key Vault ACME Certificate Management

Production-ready Infrastructure as Code (IaC) for deploying an ACME-based certificate automation platform on Azure using Bicep.

This solution provisions a secure Function App + Key Vault pattern with private networking and managed identity, and supports both initial platform creation and package-only Acmebot updates.

---

## Why this repo exists

This repo gives platform teams a practical, auditable baseline for:

- Secure certificate lifecycle automation at scale
- Key Vault-centric certificate storage and renewal
- Public + private DNS challenge support
- Repeatable deployment via Bicep and PowerShell

It is intentionally opinionated toward enterprise-friendly defaults (private endpoints, managed identity, monitoring, and explicit DNS RBAC).

---

## What gets deployed

- Resource Group
- User Assigned Managed Identity
- Key Vault (+ private endpoint)
- Storage Account (+ private endpoints for blob/file/table/queue)
- Log Analytics Workspace
- Application Insights (workspace-based)
- Azure Functions (Linux Flex Consumption, .NET Isolated)
- Acmebot package deployment via `onedeploy`
- Microsoft Entra resources (via Graph Bicep extension):
  - Security Group
  - App Registration
  - Federated Identity Credential
  - Service Principal
- Optional (when `enableCreateVirtualNetwork = true`):
  - Virtual Network + subnets
  - Network Security Group (associated to both subnets)
- Optional (when `enableCreatePrivateDnsZones = true`):
  - Private DNS zones
- Optional:
  - DNS role assignments for Public/Private DNS

## Deployment flow

- `infra/create/` provisions the full platform and deploys Acmebot during the initial build
- `infra/update/` redeploys only the Acmebot package into an existing Function App
- Both flows use the same `acmebotReleaseTag` convention: `latest`, `5.0.0`, or `v5.0.0`

---

## High-level architecture

```mermaid
flowchart LR
  U[User / Automation] --> A[Function App: Acmebot]
  A -->|MI auth| KV[Azure Key Vault]
  A --> SA[Storage Account]
  A --> DNS[Azure DNS / Private DNS]
  A --> AI[App Insights]
  AI --> LAW[Log Analytics Workspace]
  Entra[Entra App + SP + FIC] --> A
```

---

## Project structure

```text
.
├─ README.md
├─ infra/
│  ├─ bicepconfig.json
│  ├─ create/
│  │  ├─ README.md
│  │  ├─ Invoke-AzDeployment.ps1
│  │  ├─ main.bicep
│  │  └─ param.main.bicepparam
│  ├─ update/
│  │  ├─ README.md
│  │  ├─ Invoke-AzDeployment.ps1
│  │  ├─ main.bicep
│  │  └─ param.main.bicepparam
│  └─ modules/
│     ├─ app/site/extension/
│     └─ microsoft-graph/
└─ scripts/
  ├─ linux/
  │  ├─ README.md
  │  └─ Invoke-KeyVaultCertRenewal.sh
  └─ windows/
    ├─ README.md
    └─ Invoke-KeyVaultCertRenewal.ps1
```

---

## Quick start

### Prerequisites

- Azure subscription permissions to deploy resources
- Microsoft Entra permissions for Graph-backed resources
- Azure CLI + Bicep CLI
- PowerShell 7+

### 1) Review `infra/create/param.main.bicepparam`

Key settings to validate first:

- `customerName`, `environmentType`, `location`
- `sharedResourceGroupName`
- `enableCreateVirtualNetwork`, `enableCreatePrivateDnsZones`
- `azurePublicDnsZones`, `azurePrivateDnsZones`
- `acmeContacts`
- `acmeEndpoint`
- `acmeBotRenewBeforeExpiry` (percentage of certificate lifetime remaining, 0–100, default 30)
- `acmeBotUseSystemNameServer` (default `false`, useful for private DNS resolver scenarios)
- `virtualNetworkSubnetAppService` (must be at least `/27` for Flex Consumption)
- `acmebotReleaseTag` (shared by create/update; set `latest` or a pinned version like `5.0.0`)

For package redeployments, see `infra/update/Invoke-AzDeployment.ps1` and `infra/update/param.main.bicepparam`; the same `acmebotReleaseTag` convention applies.

Supported ACME endpoints in this template:

- Let's Encrypt: `https://acme-v02.api.letsencrypt.org/directory`
- Buypass: `https://api.buypass.com/acme/directory`
- GlobalSign: `https://emea.acme.atlas.globalsign.com/directory`
- ZeroSSL: `https://acme.zerossl.com/v2/DV90`
- Google Trust Services: `https://dv.acme-v02.api.pki.goog/directory`
- SSL.com RSA: `https://acme.ssl.com/sslcom-dv-rsa`
- SSL.com ECC: `https://acme.ssl.com/sslcom-dv-ecc`

### 2) Deploy

Run from `infra/create/`:

```powershell
.\Invoke-AzDeployment.ps1 `
  -targetScope sub `
  -subscriptionId "<subscription-guid>" `
  -customerName "bwc" `
  -environmentType "prod" `
  -location "westeurope" `
  -deploy
```

The script runs a `what-if` first and prompts before applying changes.

---

## Continuous integration

- [Validate Bicep](.github/workflows/validate-bicep.yml) runs on every PR/push touching `infra/**.bicep` or `.bicepparam`: builds both deployment entrypoints, builds every module individually, and validates all parameter files. Also runs [PSRule for Azure](.github/ps-rule.yaml) (`Azure.Default` baseline) against `infra/`, with the two documented Key Vault deviations (RBAC, purge protection) explicitly excluded.
- `main` requires the `validate` and `psrule` checks to pass before merging.
- [Renovate](.github/renovate.json) tracks `br/public:avm/...` Bicep module versions; [Dependabot](.github/dependabot.yml) tracks GitHub Actions versions. [Check Acmebot Release](.github/workflows/check-acmebot-release.yml) separately tracks upstream Acmebot releases.
- A failed `validate-bicep` run on `main` (i.e. a merged change that broke the build) automatically opens a tracking issue.

---

## Operations checklist

After deployment:

- Enable and enforce App Service Authentication (dashboard/API)
- Verify DNS zone discovery and TXT write/delete permissions
- Issue a test certificate (prefer staging endpoint first)
- Confirm cert appears in Key Vault
- Confirm renewals and logs in Application Insights

Helpful checks:

```powershell
az deployment sub list --query "[0].{name:name,state:properties.provisioningState,timestamp:properties.timestamp}" -o table
az functionapp config appsettings list -g <resource-group> -n <function-app-name> -o table
```

---

## Security notes

- Keep DNS credentials and secrets out of source control
- Storage Account uses managed identity authentication — shared key access is disabled (`allowSharedKeyAccess: false`); no connection strings are stored or exported
- Storage Account uses infrastructure encryption (`requireInfrastructureEncryption: true`) for double-layer at-rest encryption

- For private DNS-heavy environments, consider setting `acmeBotUseSystemNameServer = true`
- Restrict dashboard/API access via Entra and app roles where appropriate

---

## Known design choices in this repo

- This repo deploys the latest release asset from GitHub using `onedeploy`.
- DNS role assignment modules support cross-subscription scopes via explicit subscription parameters
- The baseline is tuned for Azure public cloud and Acmebot v5 behavior
- Key Vault uses Access Policies (not RBAC) to preserve compatibility with Application Gateway certificate integration
- Key Vault soft delete is enabled with a 90-day retention period; purge protection is intentionally left disabled so certificates can be force-purged and re-issued under the same name without waiting out the retention window. Once purge protection is enabled it cannot be turned off again, so weigh this trade-off before flipping it on for a given vault.
- NSG is only created when `enableCreateVirtualNetwork = true`; when using an existing VNet, NSG management is assumed to be handled by the existing network
- `dependsOn` helpers are intentionally retained for readability and the linter rule is disabled in `infra/bicepconfig.json`

---

## Related docs in this repository

- `infra/create/README.md`
- `infra/update/README.md`
- `infra/modules/app/site/extension/README.md`
- `infra/modules/microsoft-graph/readme.md`
- `infra/modules/microsoft-graph/*/README.md`
- `scripts/linux/README.md`
- `scripts/windows/README.md`

---

## Upstream references

- Acmebot project: [polymind-inc/acmebot](https://github.com/polymind-inc/acmebot)
- Acmebot docs: [Acmebot guide](https://acmebot.dev/guide/)
- Acmebot configuration reference: [Acmebot configuration reference](https://acmebot.dev/reference/configuration)
- Azure Bicep docs: [Azure Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

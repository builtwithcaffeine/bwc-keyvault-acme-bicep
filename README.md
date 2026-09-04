# Azure Key Vault ACME Certificate Management

Production-ready Azure infrastructure for automating ACME certificate issuance and renewal with Bicep, Azure Functions, Key Vault, managed identity, private endpoints, and Azure DNS.

This repository contains a public, repeatable deployment baseline. It supports three network topologies: a self-contained environment, a hub-and-spoke deployment, and deployment into an existing network.

## What this provides

- Automated ACME certificate issuance and renewal through Acmebot
- Certificates stored in Azure Key Vault
- Azure DNS public and private DNS-01 challenge support
- Private endpoints for Key Vault, Storage, and the Function App
- Managed identity authentication without storage connection strings
- Optional hub-and-spoke peering and cross-subscription resource references
- Application Insights and Log Analytics integration
- Repeatable deployment with Bicep and PowerShell

## Deployed resources

The create flow provisions:

- Resource group
- User-assigned managed identities
- Key Vault
- Storage Account and private endpoints
- Log Analytics workspace
- Workspace-based Application Insights
- Linux Flex Consumption Function App running .NET Isolated Acmebot
- Acmebot package through OneDeploy
- Microsoft Entra security group, app registration, federated identity credential, and service principal
- Optional Virtual Network, subnets, Network Security Group, private DNS zones, and hub peering

## Network topologies

Set `networkTopology` in `infra/create/param.main.bicepparam` to one of these values:

| Value | Network | Private DNS | Use when |
| --- | --- | --- | --- |
| `standalone` | Creates a new VNet and two subnets | Creates six private DNS zones in the workload resource group | The environment is self-contained |
| `hubSpoke` | Creates a new spoke VNet and bidirectionally peers it to `sharedHub` | Uses existing zones in `privateDnsZoneResourceGroupName` and links them to the spoke | A central hub owns networking and private DNS |
| `existing` | Uses an existing VNet and two existing subnets | Uses existing zones and links them to the VNet | Networking is managed outside this deployment |

### Parameter groups

- `spoke*` — address space and subnet prefixes for `standalone` and `hubSpoke`
- `sharedHub*` — subscription, resource group, and VNet name for `hubSpoke`
- `existing*` — subscription, resource group, VNet, private endpoint subnet, and App Service subnet for `existing`
- `privateDnsZone*` — subscription and resource group containing the six existing `privatelink.*` zones for `hubSpoke` and `existing`

Parameters for other topologies remain in the single example file but are ignored by the selected topology. Keep them accurate if you switch topology during testing.

For `hubSpoke`, the spoke address space must not overlap the hub address space. The deployment identity needs permission to create the spoke, private DNS links, and the reverse peering in the hub subscription.

For `existing`, the private endpoint subnet must allow private endpoints and the App Service subnet must already be delegated to `Microsoft.App/environments` and be at least `/27` for Flex Consumption. Existing subnet and NSG configuration is not changed by this deployment.

## Deployment scope

`infra/create/main.bicep` uses `targetScope = 'subscription'`. Use the create wrapper with `-targetScope sub` and provide `-subscriptionId` for the subscription containing the workload resource group.

The wrapper contains generic management-group and tenant scope handling, but those scopes are not supported by the current create entrypoint. They require a template whose `targetScope` matches the selected deployment scope.

## Quick start

### Prerequisites

- Azure subscription access to the workload subscription
- Microsoft Entra permissions for the Graph-backed resources
- Permission to create or reference resources in hub and private DNS subscriptions
- Azure CLI with Bicep support
- PowerShell 7+

### 1. Configure parameters

Review `infra/create/param.main.bicepparam` and set:

- `customerName`, `environmentType`, `location`, and `locationShortCode`
- `networkTopology`
- The relevant `spoke*`, `sharedHub*`, `existing*`, and `privateDnsZone*` values
- `azurePublicDnsZones` and optional `azurePrivateDnsZones`
- `acmeContacts`, `acmeEndpoint`, and `acmeBotRenewBeforeExpiry`
- `acmebotReleaseTag` (`latest` or a pinned version such as `5.1.4`)

For hub/spoke deployments, verify that all six private DNS zones already exist in the configured private DNS subscription and resource group.

### 2. Validate and preview

Run the wrapper from any directory. Its default template and parameter paths resolve from `infra/create`:

```powershell
.\infra\create\Invoke-AzDeployment.ps1 `
  -targetScope sub `
  -subscriptionId "<subscription-guid>" `
  -customerName "bwc" `
  -environmentType "dev" `
  -location "westeurope"
```

The wrapper checks Azure CLI and Bicep, authenticates, displays identity and RBAC information, and runs an Azure `what-if`. Add `-deploy` only after reviewing the preview.

```powershell
.\infra\create\Invoke-AzDeployment.ps1 `
  -targetScope sub `
  -subscriptionId "<subscription-guid>" `
  -customerName "bwc" `
  -environmentType "prod" `
  -location "westeurope" `
  -deploy
```

The wrapper also supports PowerShell's `-WhatIf` and `-Confirm` common parameters, plus service-principal authentication for scripted use.

### 3. Update Acmebot

After the platform exists, use `infra/update/` to redeploy only the Acmebot package. This does not recreate the Function App, Key Vault, networking, or supporting resources.

## Deployment flow

- `infra/create/` creates the full platform and deploys Acmebot
- `infra/update/` redeploys the Acmebot package into an existing Function App
- Both flows use `acmebotReleaseTag`: `latest`, `5.0.0`, or `v5.0.0`
- The release-check workflow monitors upstream Acmebot releases and opens an update pull request

## Operations checklist

After deployment:

- Enable and enforce Function App Authentication through Microsoft Entra ID
- Verify public and private DNS zone discovery and TXT write/delete permissions
- Issue a test certificate using an ACME staging endpoint first
- Confirm the certificate appears in Key Vault
- Confirm renewal execution and failures in Application Insights
- Confirm private endpoint DNS resolution from the integrated Function App network

Useful checks:

```powershell
az deployment sub list --query "[0].{name:name,state:properties.provisioningState,timestamp:properties.timestamp}" -o table
az functionapp config appsettings list -g <resource-group> -n <function-app-name> -o table
az network private-dns link vnet list -g <private-dns-resource-group> -z privatelink.vaultcore.azure.net -o table
```

## Security and design notes

- Keep DNS credentials and secrets out of source control.
- Azure DNS role assignments use explicit subscription and resource group scopes.
- Storage uses managed identity authentication; shared key access is disabled and no connection strings are exported.
- Storage uses infrastructure encryption for double-layer at-rest encryption.
- Key Vault uses access policies rather than RBAC to preserve Application Gateway certificate compatibility.
- Key Vault soft delete is enabled for 90 days. Purge protection is intentionally disabled so certificates can be force-purged and re-issued under the same name; evaluate this trade-off before enabling it.
- The Acmebot package is downloaded from the upstream GitHub release and deployed with OneDeploy. Pin a release for controlled production rollouts.
- Cross-subscription deployments require appropriate permissions in every referenced subscription.

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
│  ├─ modules/
│  │  ├─ app/site/extension/
│  │  └─ microsoft-graph/
│  └─ ...
└─ scripts/
   ├─ linux/
   └─ windows/
```

## Continuous integration

- `validate-bicep.yml` builds the create and update entrypoints, modules, and parameter files.
- PSRule for Azure runs against `infra/` using the `Azure.Default` baseline.
- Renovate tracks AVM Bicep module versions.
- Dependabot tracks GitHub Actions versions.
- `check-acmebot-release.yml` monitors upstream Acmebot releases.

## Related documentation

- [Create deployment](infra/create/README.md)
- [Update deployment](infra/update/README.md)
- [OneDeploy module](infra/modules/app/site/extension/README.md)
- [Microsoft Graph modules](infra/modules/microsoft-graph/readme.md)
- [Linux renewal script](scripts/linux/README.md)
- [Windows renewal script](scripts/windows/README.md)

## Upstream references

- [Acmebot project](https://github.com/polymind-inc/acmebot)
- [Acmebot guide](https://acmebot.dev/guide/)
- [Acmebot configuration reference](https://acmebot.dev/reference/configuration)
- [Azure Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

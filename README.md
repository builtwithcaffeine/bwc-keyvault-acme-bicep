# Azure Key Vault ACME Certificate Management

This repository contains Azure Bicep templates for deploying an automated ACME (Automated Certificate Management Environment) certificate management solution using Azure Key Vault. The solution automates the process of requesting, renewing, and managing SSL/TLS certificates from ACME certificate authorities like Let's Encrypt.

## Overview

This infrastructure-as-code solution deploys the following Azure resources:

- **Azure Key Vault** - Secure storage for certificates and secrets
- **User Managed Identity** - Identity for automated certificate management
- **Azure Function App** - Automated certificate renewal logic
- **App Service Plan** - Hosting for the Function App
- **Storage Account** - Required for Function App runtime
- **Log Analytics Workspace** - Centralized logging and monitoring
- **Application Insights** - Application performance monitoring
- **Virtual Network** (optional) - Network isolation and security
- **Private DNS Zones** (optional) - Private endpoint DNS resolution
- **Microsoft Graph Integration** - Application registration for authentication

## Prerequisites

Before deploying this solution, ensure you have:

- **Azure Subscription** with appropriate permissions
- **Azure CLI** installed and up-to-date
- **Bicep CLI** installed and up-to-date
- **PowerShell** 7.0 or later
- **Contributor** or **Owner** role on the target subscription
- **Application Administrator** role in Azure AD (for app registration)

## Project Structure

```
.
├── main.bicep                          # Main Bicep template
├── param.main.bicepparam               # Parameters file
├── Invoke-AzDeployment.ps1             # Deployment script
├── bicepconfig.json                    # Bicep configuration
└── modules/
    └── microsoft-graph/                # Microsoft Graph integration modules
        ├── applications/               # App registration deployment
        ├── servicePrincipals/          # Service principal management
        ├── federatedIdentityCredentials/ # Federated identity credentials
        ├── groups/                     # Azure AD group management
        ├── users/                      # Azure AD user management
        ├── oauth2PermissionGrants/     # OAuth2 permissions
        └── appRoleAssignedTo/          # App role assignments
```

## Configuration

### Parameters File

Edit the `param.main.bicepparam` file to configure your deployment:

```bicep
// Core Configuration
param customerName = 'bwc'              # Customer/organization identifier
param environmentType = 'dev'           # Environment: dev, acc, or prod
param location = 'westeurope'           # Azure region
param locationShortCode = 'weu'         # Location abbreviation
param deployedBy = ''                   # Deployment identifier

// Azure Network Configuration
param enableCreateVirtualNetwork = true # Create new virtual network
param virtualNetworkAddressPrefix = '10.0.0.0/24'
param virtualNetworkSubnetShared = '10.0.0.0/28'
param virtualNetworkSubnetAppService = '10.0.0.16/28'

// Key Vault Configuration
param createWithKeyVault = true         # Create new Key Vault
param existingKeyVaultResourceGroup = '' # Use existing KV (optional)
param existingKeyVaultName = ''         # Existing KV name (optional)

// Private DNS Configuration
param enableCreatePrivateDnsZones = false # Create private DNS zones
```

### Resource Naming Convention

Resources follow Azure naming best practices:

- Resource Group: `rg-x-{customer}-kvacme-{env}-{location}`
- Key Vault: `kv-{customer}-kvacme-{env}-{location}`
- Function App: `func-{customer}-kvacme-{env}-{location}`
- Storage Account: `st{customer}kvacme{env}{location}`
- Managed Identity: `id-{customer}-kvacme-{env}-{location}`

## Deployment

### Option 1: Using the PowerShell Script (Recommended)

The repository includes a comprehensive deployment script with validation and error handling:

```powershell
# Deploy to subscription scope
.\Invoke-AzDeployment.ps1 `
    -targetScope sub `
    -subscriptionId "b67e1026-b589-41e2-b41f-73f8803f71a0" `
    -customerName bwc `
    -environmentType dev `
    -location westeurope `
    -deploy
```

#### Script Parameters

- **`-targetScope`** - Deployment scope: `tenant`, `mgmt`, or `sub`
- **`-subscriptionId`** - Azure subscription ID (36-character GUID)
- **`-customerName`** - Customer/organization identifier
- **`-environmentType`** - Environment type: `dev`, `acc`, or `prod`
- **`-location`** - Azure region for deployment
- **`-deploy`** - Switch to execute the deployment (without this, it validates only)

### Option 2: Using Azure CLI

```powershell
# Login to Azure
az login

# Set subscription
az account set --subscription "b67e1026-b589-41e2-b41f-73f8803f71a0"

# Deploy using Bicep
az deployment sub create `
    --name "kvacme-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --location westeurope `
    --template-file .\main.bicep `
    --parameters .\param.main.bicepparam
```

### Option 3: What-If Validation

Preview changes before deployment:

```powershell
az deployment sub what-if `
    --location westeurope `
    --template-file .\main.bicep `
    --parameters .\param.main.bicepparam
```

## Deployment Features

The `Invoke-AzDeployment.ps1` script includes:

- ✅ Azure CLI and Bicep version validation
- ✅ Automatic authentication handling
- ✅ Parameter validation and sanitization
- ✅ Location short code mapping
- ✅ Deployment tracking with unique GUIDs
- ✅ Comprehensive error handling
- ✅ Support for service principal authentication
- ✅ What-if preview capability

## Post-Deployment Configuration

After deployment, you'll need to:

1. **Configure ACME Provider**
   - Set up Let's Encrypt or other ACME CA credentials
   - Configure ACME account in Key Vault

2. **Configure DNS Validation**
   - Set up DNS provider credentials
   - Configure automated DNS challenge handling

3. **Set Function App Settings**
   - Configure certificate renewal schedules
   - Set notification endpoints
   - Configure retry policies

4. **Grant Permissions**
   - Ensure managed identity has Key Vault certificate permissions
   - Configure DNS provider API access

## Monitoring and Maintenance

### Log Analytics

Monitor deployments and operations through Log Analytics workspace:

```powershell
# Query Function App logs
az monitor log-analytics query `
    -w <workspace-id> `
    --analytics-query "FunctionAppLogs | where TimeGenerated > ago(24h)"
```

### Application Insights

View application metrics and traces in Application Insights for troubleshooting and performance monitoring.

## Security Considerations

- All secrets are stored in Azure Key Vault
- Managed identities are used for authentication (no stored credentials)
- Private endpoints can be enabled for network isolation
- RBAC is enforced at all resource levels
- Audit logging is enabled by default

## Troubleshooting

### Common Issues

1. **Deployment fails with permission errors**
   - Ensure you have Contributor/Owner role on subscription
   - Verify Application Administrator role in Azure AD

2. **Key Vault name conflicts**
   - Key Vault names must be globally unique
   - Modify `customerName` or `locationShortCode` parameters

3. **Virtual network address conflicts**
   - Adjust `virtualNetworkAddressPrefix` to avoid conflicts
   - Ensure subnet ranges don't overlap with existing networks

## Contributing

When contributing to this repository:

1. Follow Azure naming conventions
2. Test deployments in dev environment first
3. Update documentation for new features
4. Include parameter examples in bicepparam files

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:

- Create an issue in the repository
- Review existing documentation in `modules/` folders
- Check Azure documentation for service-specific guidance

## Additional Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Key Vault Documentation](https://learn.microsoft.com/azure/key-vault/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [ACME Protocol Specification](https://datatracker.ietf.org/doc/html/rfc8555)

---

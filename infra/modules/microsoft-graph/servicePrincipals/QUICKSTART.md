# 🚀 Quick Start Guide

## Microsoft Graph Service Principals Module

Get service principals configured for enterprise authentication in **under 3 minutes**!

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Microsoft Entra permissions: **Application Administrator** or **Global Administrator**
- Existing Microsoft Entra application (or use our [Applications module](../applications/QUICKSTART.md))

```bash
# Verify prerequisites
az ad signed-in-user show --query "displayName"
az bicep version
```

## 🎯 Option 1: Basic Service Principal (1 minute)

### Step 1: Create Parameter File

Create `quickstart-sp.bicepparam`:

```bicep
using 'modules/microsoft-graph/servicePrincipals/main.bicep'

// Basic service principal from existing application
param appId = '12345678-1234-1234-1234-123456789012' // Your application ID
param tags = ['Environment:Production', 'Type:ServicePrincipal']
```

### Step 2: Deploy

```bash
# Deploy service principal
az deployment group create \
  --resource-group "rg-quickstart" \
  --template-file "modules/microsoft-graph/servicePrincipals/main.bicep" \
  --parameters "quickstart-sp.bicepparam" \
  --name "quickstart-sp-deployment"
```

### Step 3: Get Service Principal Details

```bash
# Get service principal information
az deployment group show \
  --resource-group "rg-quickstart" \
  --name "quickstart-sp-deployment" \
  --query "properties.outputs.{servicePrincipalId:servicePrincipalId.value,appId:appId.value,displayName:displayName.value}"
```

**🎉 Done! Your service principal is ready for authentication.**

---

## 🎯 Option 2: Service Principal with Owners (2 minutes)

### Step 1: Create Enhanced Parameter File

Create `enterprise-sp.bicepparam`:

```bicep
using 'modules/microsoft-graph/servicePrincipals/main.bicep'

// Service principal with ownership and management
param appId = '12345678-1234-1234-1234-123456789012'
param accountEnabled = true
param appRoleAssignmentRequired = true // Require role assignment for access
param ownerIds = [
  '11111111-1111-1111-1111-111111111111'   // Primary owner object ID
  '22222222-2222-2222-2222-222222222222'   // Admin owner object ID
]
param tags = [
  'Environment:Production'
  'Owner:Platform-Team'
  'CostCenter:IT-001'
  'Application:Enterprise-API'
]
```

### Step 2: Deploy Enterprise Service Principal

```bash
az deployment group create \
  --resource-group "rg-enterprise" \
  --template-file "modules/microsoft-graph/servicePrincipals/main.bicep" \
  --parameters "enterprise-sp.bicepparam" \
  --name "enterprise-sp-deployment"
```

**🎉 Enterprise service principal with owners is ready!**

---

## 🎯 Option 3: Multi-Environment Service Principals (3 minutes)

### Step 1: Create Environment Template

Create `multi-env-sp.bicep`:

```bicep
targetScope = 'resourceGroup'

@allowed(['dev', 'staging', 'prod'])
param environment string

param baseAppId string
param ownerIds array = []

// Environment-specific configurations
var environmentConfig = {
  dev: {
    accountEnabled: true
    appRoleAssignmentRequired: false
    tags: ['Environment:Development', 'Owner:Dev-Team']
  }
  staging: {
    accountEnabled: true
    appRoleAssignmentRequired: true
    tags: ['Environment:Staging', 'Owner:QA-Team']
  }
  prod: {
    accountEnabled: true
    appRoleAssignmentRequired: true
    tags: ['Environment:Production', 'Owner:Platform-Team', 'Critical:High']
  }
}

module servicePrincipal 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'sp-${environment}'
  params: {
    appId: baseAppId
    accountEnabled: environmentConfig[environment].accountEnabled
    appRoleAssignmentRequired: environmentConfig[environment].appRoleAssignmentRequired
    ownerIds: ownerIds
    tags: environmentConfig[environment].tags
  }
}

output servicePrincipalId string = servicePrincipal.outputs.servicePrincipalId
output environment string = environment
```

### Step 2: Deploy Across Environments

```bash
# Development environment
az deployment group create \
  --resource-group "rg-dev" \
  --template-file "multi-env-sp.bicep" \
  --parameters environment=dev baseAppId=<your-app-id> \
  --name "dev-sp-deployment"

# Production environment
az deployment group create \
  --resource-group "rg-prod" \
  --template-file "multi-env-sp.bicep" \
  --parameters environment=prod baseAppId=<your-app-id> ownerIds='["11111111-1111-1111-1111-111111111111"]' \
  --name "prod-sp-deployment"
```

**🎉 Multi-environment service principals deployed!**

---

## 🛠️ Common Operations

### Get Service Principal Information

```bash
# List all service principals
az ad sp list --query "[].{displayName:displayName,appId:appId,objectId:id}" --output table

# Get specific service principal
az ad sp show --id <object-id> --query "{displayName:displayName,appId:appId,accountEnabled:accountEnabled}"

# Find service principal by app ID
az ad sp list --filter "appId eq '<app-id>'" --query "[0].{displayName:displayName,objectId:id}"
```

### Manage Service Principal

```bash
# Enable/disable service principal
az ad sp update --id <object-id> --set accountEnabled=true

# Add owner
az ad sp owner add --id <sp-object-id> --owner-object-id <user-object-id>

# List owners
az ad sp owner list --id <sp-object-id> --query "[].displayName"
```

### Service Principal Authentication

```bash
# Create client secret (for authentication)
az ad sp credential reset --id <object-id> --display-name "Production Secret"

# List credentials
az ad sp credential list --id <object-id>
```

## 🔍 Troubleshooting

### Issue: Service Principal Already Exists

**Error**: `Another object with the same value for property appId already exists`

**Solution**: Service principal already exists for this application. Get existing one:

```bash
az ad sp list --filter "appId eq '<your-app-id>'" --query "[0].id" -o tsv
```

### Issue: Permission Denied

**Error**: `Insufficient privileges to complete the operation`

**Solution**: Verify you have the required permissions:

```bash
# Check your roles
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) \
  --query "[].roleDefinitionName" -o table
```

Ensure you have **Application Administrator** or **Global Administrator** role.

### Issue: Cannot Add Owner

**Error**: `Request contains a property that cannot be updated`

**Solution**: Verify the owner's object ID is correct:

```bash
# Get user object ID
az ad user show --id "user@contoso.com" --query id -o tsv
```

## 🔗 Quick Reference

### Essential Object IDs

```bash
# Get your own object ID
az ad signed-in-user show --query id -o tsv

# Get application object ID from app ID
az ad app list --filter "appId eq '<app-id>'" --query "[0].id" -o tsv

# Get service principal object ID from app ID
az ad sp list --filter "appId eq '<app-id>'" --query "[0].id" -o tsv
```

### Common App IDs (Microsoft Services)

```bash
# Microsoft Graph
00000003-0000-0000-c000-000000000000

# Microsoft Entra ID / Azure AD Graph (legacy)
00000002-0000-0000-c000-000000000000

# Microsoft 365 Management APIs
c5393580-f805-4401-95e8-94b7a6ef2fc2
```

## 🔗 Next Steps

- 📖 **[Full Documentation](README.md)** - Complete module reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Advanced usage scenarios
- 🔐 **[App Role Assignments](../appRoleAssignedTo/QUICKSTART.md)** - Assign permissions
- 👥 **[Groups Module](../groups/QUICKSTART.md)** - Group management
- 👤 **[Users Module](../users/QUICKSTART.md)** - User references

## 💡 Pro Tips

1. **Use descriptive tags** - Tag service principals for easy identification and cost management
2. **Enable role assignment requirement** - Use `appRoleAssignmentRequired: true` for production security
3. **Assign owners** - Always assign responsible owners for service principal management
4. **Monitor authentication** - Set up alerts for service principal sign-in activities
5. **Regular secret rotation** - Rotate client secrets regularly for security

---

**⚡ Your service principals are ready for enterprise authentication!** 🚀

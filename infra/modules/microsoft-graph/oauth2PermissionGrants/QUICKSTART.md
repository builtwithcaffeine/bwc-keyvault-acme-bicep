# 🚀 Quick Start Guide

## Microsoft Graph OAuth2 Permission Grants Module

Grant OAuth2 permissions for secure API access in **under 3 minutes**!

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Microsoft Entra permissions: **Application Administrator** or **Global Administrator**
- Existing service principal and resource API
- Understanding of OAuth2 permission scopes

```bash
# Verify prerequisites
az ad signed-in-user show --query "displayName"
az bicep version
```

## 🎯 Option 1: Basic API Permission Grant (1 minute)

### Step 1: Get Required IDs

```bash
# Get your app's service principal ID
CLIENT_SP_ID=$(az ad sp list --filter "displayName eq 'Your App Name'" --query "[0].id" -o tsv)

# Get Microsoft Graph resource ID (common scenario)
RESOURCE_SP_ID=$(az ad sp list --filter "appId eq '00000003-0000-0000-c000-000000000000'" --query "[0].id" -o tsv)

echo "Client SP: $CLIENT_SP_ID"
echo "Resource SP: $RESOURCE_SP_ID"
```

### Step 2: Create Parameter File

Create `quickstart-permission.bicepparam`:

```bicep
using 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep'

// Basic Microsoft Graph permission grant
param clientId = '12345678-1234-1234-1234-123456789012' // Your service principal object ID
param resourceId = '98765432-1234-1234-1234-987654321098' // Microsoft Graph service principal ID
param scope = 'User.Read Directory.Read.All'
param consentType = 'AllPrincipals' // Admin consent for all users
```

### Step 3: Deploy Permission Grant

```bash
# Deploy permission grant
az deployment group create \
  --resource-group "rg-quickstart" \
  --template-file "modules/microsoft-graph/oauth2PermissionGrants/main.bicep" \
  --parameters "quickstart-permission.bicepparam" \
  --name "quickstart-permission-deployment"
```

**🎉 Done! Your app can now access Microsoft Graph APIs.**

---

## 🎯 Option 2: Multi-Scope Permission Grant (2 minutes)

### Step 1: Create Enhanced Parameter File

Create `multi-scope-permission.bicepparam`:

```bicep
using 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep'

// Comprehensive Microsoft Graph permissions
param clientId = '12345678-1234-1234-1234-123456789012'
param resourceId = '98765432-1234-1234-1234-987654321098' // Microsoft Graph
param scope = 'User.Read User.Read.All Directory.Read.All Group.Read.All Application.Read.All'
param consentType = 'AllPrincipals'
```

### Step 2: Deploy Enhanced Permissions

```bash
az deployment group create \
  --resource-group "rg-api-access" \
  --template-file "modules/microsoft-graph/oauth2PermissionGrants/main.bicep" \
  --parameters "multi-scope-permission.bicepparam" \
  --name "multi-scope-permission-deployment"
```

**🎉 Multi-scope permissions granted for comprehensive API access!**

---

## 🎯 Option 3: Multi-API Permission Setup (3 minutes)

### Step 1: Create Multi-API Template

Create `multi-api-permissions.bicep`:

```bicep
targetScope = 'resourceGroup'

param clientServicePrincipalId string
param environment string = 'production'

// Microsoft Graph permissions
module microsoftGraphPermissions 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'msgraph-permissions-${environment}'
  params: {
    clientId: clientServicePrincipalId
    resourceId: '11111111-1111-1111-1111-111111111111' // Microsoft Graph service principal object ID
    scope: 'User.Read Directory.Read.All Group.Read.All'
    consentType: 'AllPrincipals'
  }
}

// Azure Active Directory Graph permissions (legacy)
module aadGraphPermissions 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'aadgraph-permissions-${environment}'
  params: {
    clientId: clientServicePrincipalId
    resourceId: '22222222-2222-2222-2222-222222222222' // AAD Graph service principal object ID
    scope: 'User.Read Directory.Read.All'
    consentType: 'AllPrincipals'
  }
}

// SharePoint Online permissions
module sharePointPermissions 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'sharepoint-permissions-${environment}'
  params: {
    clientId: clientServicePrincipalId
    resourceId: '33333333-3333-3333-3333-333333333333' // SharePoint Online service principal object ID
    scope: 'Sites.Read.All Web.Read'
    consentType: 'AllPrincipals'
  }
}

output microsoftGraphGrantId string = microsoftGraphPermissions.outputs.oauth2PermissionGrantId
output aadGraphGrantId string = aadGraphPermissions.outputs.oauth2PermissionGrantId
output sharePointGrantId string = sharePointPermissions.outputs.oauth2PermissionGrantId
```

### Step 2: Deploy Multi-API Permissions

```bash
# Get your service principal ID
CLIENT_SP_ID=$(az ad sp list --filter "displayName eq 'Your App'" --query "[0].id" -o tsv)

# Deploy all API permissions
az deployment group create \
  --resource-group "rg-enterprise" \
  --template-file "multi-api-permissions.bicep" \
  --parameters clientServicePrincipalId="$CLIENT_SP_ID" environment="production" \
  --name "multi-api-permissions-deployment"
```

**🎉 Multi-API permission grants configured for enterprise access!**

---

## 🛠️ Common Operations

### List Permission Grants

```bash
# List all OAuth2 permission grants for a service principal
az ad sp oauth2-permission-grant list --id <service-principal-id>

# List grants with specific resource
az ad sp oauth2-permission-grant list --id <service-principal-id> \
  --filter "resourceId eq '<resource-sp-id>'"

# Show detailed grant information
az ad oauth2-permission-grant show --id <grant-id>
```

### Manage Permission Scopes

```bash
# Update permission scopes
az ad oauth2-permission-grant update --id <grant-id> --scope "User.Read Directory.Read.All"

# Remove specific permission grant
az ad oauth2-permission-grant delete --id <grant-id>
```

### Check API Permissions

```bash
# List available permissions for Microsoft Graph
az ad sp show --id 00000003-0000-0000-c000-000000000000 \
  --query "oauth2PermissionScopes[].{value:value,displayName:displayName}" -o table

# Check current permissions for your app
az ad sp show --id <your-sp-id> --query "oauth2PermissionScopes[].value" -o table
```

## 🔍 Troubleshooting

### Issue: Permission Already Granted

**Error**: `Permission grant already exists for this client and resource`

**Solution**: Check existing grants and update if needed:

```bash
# Find existing grant
az ad sp oauth2-permission-grant list --id <client-sp-id> \
  --filter "resourceId eq '<resource-sp-id>'" \
  --query "[0].{id:id,scope:scope}"

# Update existing grant instead of creating new one
az ad oauth2-permission-grant update --id <existing-grant-id> --scope "User.Read Directory.Read.All"
```

### Issue: Invalid Scope

**Error**: `The specified scope is invalid`

**Solution**: Verify the scope exists for the target API:

```bash
# List available scopes for Microsoft Graph
az ad sp show --id 00000003-0000-0000-c000-000000000000 \
  --query "oauth2PermissionScopes[?contains(value, 'User')].{value:value,description:description}" -o table
```

### Issue: Insufficient Privileges

**Error**: `Insufficient privileges to complete the operation`

**Solution**: Verify admin consent permissions:

```bash
# Check your roles
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) \
  --query "[].roleDefinitionName" -o table
```

Ensure you have **Application Administrator** or **Global Administrator** role.

### Issue: Resource Not Found

**Error**: `Resource service principal not found`

**Solution**: Verify the resource service principal exists:

```bash
# Find service principal by app ID
az ad sp list --filter "appId eq '<app-id>'" --query "[0].{id:id,displayName:displayName}"

# List common Microsoft service principals
az ad sp list --filter "startswith(displayName, 'Microsoft')" \
  --query "[].{displayName:displayName,appId:appId}" -o table
```

## 🔗 Quick Reference

### Common Microsoft APIs

| Service | App ID | Common Scopes |
| --------- | -------- | --------------- |
| Microsoft Graph | `00000003-0000-0000-c000-000000000000` | `User.Read`, `Directory.Read.All`, `Group.Read.All` |
| Microsoft Entra ID / Azure AD Graph (legacy) | `00000002-0000-0000-c000-000000000000` | `User.Read`, `Directory.Read.All` |
| SharePoint Online | `00000003-0000-0ff1-ce00-000000000000` | `Sites.Read.All`, `Web.Read` |
| Exchange Online | `00000002-0000-0ff1-ce00-000000000000` | `Mail.Read`, `Calendars.Read` |

### Permission Scope Categories

```bash
# Read permissions
User.Read, Directory.Read.All, Group.Read.All

# Write permissions
User.ReadWrite, Directory.ReadWrite.All, Group.ReadWrite.All

# Administrative permissions
User.ReadWrite.All, Application.ReadWrite.All, RoleManagement.ReadWrite.Directory
```

### Essential Commands

```bash
# Get service principal ID by display name
az ad sp list --filter "displayName eq 'App Name'" --query "[0].id" -o tsv

# Get service principal ID by app ID
az ad sp list --filter "appId eq '<app-id>'" --query "[0].id" -o tsv

# Get Microsoft Graph service principal ID
az ad sp list --filter "appId eq '00000003-0000-0000-c000-000000000000'" --query "[0].id" -o tsv
```

## 🔗 Next Steps

- 📖 **[Full Documentation](README.md)** - Complete module reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Advanced permission scenarios
- 🏢 **[Service Principals](../servicePrincipals/QUICKSTART.md)** - Create app identities
- 🔐 **[App Role Assignments](../appRoleAssignedTo/QUICKSTART.md)** - Assign application roles
- 👥 **[Applications](../applications/QUICKSTART.md)** - Register applications

## 💡 Pro Tips

1. **Start with minimal permissions** - Grant only the scopes your app actually needs
2. **Use admin consent** - Set `consentType: 'AllPrincipals'` for organization-wide apps
3. **Document your permissions** - Keep track of why each scope is needed
4. **Regular permission audits** - Review and remove unused permissions
5. **Principle of least privilege** - Avoid over-privileged applications
6. **Test permissions** - Verify your app works with granted permissions before deployment

---

**🔐 Your OAuth2 permissions are configured for secure API access!** 🚀

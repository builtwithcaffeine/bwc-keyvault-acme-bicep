# 🚀 Quick Start Guide

## Microsoft Graph App Role Assignments Module

Assign app roles to users, groups, and service principals in **under 3 minutes**!

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Azure AD permissions: **Application Administrator** or **Global Administrator**
- Existing Azure AD application with defined app roles
- Principal IDs (users, groups, or service principals) to assign roles to

```bash
# Verify prerequisites
az ad signed-in-user show --query "displayName"
az bicep version
```

## 🎯 Option 1: Basic Service Principal Role Assignment (1 minute)

### Step 1: Get Required Information

```bash
# Get your API application's service principal and app roles
API_SP_ID=$(az ad sp list --filter "displayName eq 'My API App'" --query "[0].id" -o tsv)
APP_ROLE_ID=$(az ad sp show --id $API_SP_ID --query "appRoles[?value=='Data.Read'].id" -o tsv)

# Get client service principal ID
CLIENT_SP_ID=$(az ad sp list --filter "displayName eq 'My Client App'" --query "[0].id" -o tsv)

echo "API Service Principal: $API_SP_ID"
echo "App Role ID: $APP_ROLE_ID"
echo "Client Service Principal: $CLIENT_SP_ID"
```

### Step 2: Create Parameter File

Create `quickstart-role.bicepparam`:

```bicep
using 'modules/microsoft-graph/appRoleAssignedTo/main.bicep'

// Basic app role assignment
param appRoleId = '12345678-1234-1234-1234-123456789abc' // App role ID from step 1
param principalId = '98765432-1234-1234-1234-987654321def' // Client service principal ID
param resourceId = '11111111-2222-3333-4444-555555555555' // API service principal ID
param resourceDisplayName = 'My API Application'
param principalDisplayName = 'My Client Application'
param principalType = 'ServicePrincipal'
param appRoleValue = 'Data.Read'
param environmentName = 'production'
```

### Step 3: Deploy Role Assignment

```bash
# Deploy app role assignment
az deployment group create \
  --resource-group "rg-quickstart" \
  --template-file "modules/microsoft-graph/appRoleAssignedTo/main.bicep" \
  --parameters "quickstart-role.bicepparam" \
  --name "quickstart-role-deployment"
```

**🎉 Done! Your service principal now has API access with the assigned role.**

---

## 🎯 Option 2: User Role Assignment with Validation (2 minutes)

### Step 1: Create User Assignment Parameter File

Create `user-role.bicepparam`:

```bicep
using 'modules/microsoft-graph/appRoleAssignedTo/main.bicep'

// User role assignment with admin access
param appRoleId = '87654321-4321-4321-4321-876543210abc' // Admin role ID
param principalId = '55555555-6666-7777-8888-999999999999' // User object ID
param resourceId = '11111111-2222-3333-4444-555555555555' // API service principal ID
param resourceDisplayName = 'Enterprise API'
param principalDisplayName = 'John Doe (Admin)'
param principalType = 'User'
param appRoleValue = 'Admin'
param environmentName = 'production'
```

### Step 2: Deploy User Assignment

```bash
# Get user object ID
USER_ID=$(az ad user show --id "admin@contoso.com" --query "id" -o tsv)

# Deploy user role assignment
az deployment group create \
  --resource-group "rg-admin-access" \
  --template-file "modules/microsoft-graph/appRoleAssignedTo/main.bicep" \
  --parameters "user-role.bicepparam" principalId="$USER_ID" \
  --name "user-role-deployment"
```

### Step 3: Verify Assignment

```bash
# Check assignment was created
az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/users/$USER_ID/appRoleAssignments" \
  --query "value[?resourceId=='$API_SP_ID'].{appRoleId:appRoleId,resourceDisplayName:resourceDisplayName}"
```

**🎉 User role assignment complete with verification!**

---

## 🎯 Option 3: Multi-Principal Role Assignment (3 minutes)

### Step 1: Create Multi-Assignment Template

Create `multi-role-assignments.bicep`:

```bicep
targetScope = 'resourceGroup'

param apiServicePrincipalId string
param environment string = 'production'

// Different roles for different principals
var roleAssignments = [
  {
    principalId: 'admin-user-id'
    principalType: 'User'
    principalDisplayName: 'API Administrator'
    appRoleValue: 'Admin'
    description: 'Full administrative access'
  }
  {
    principalId: 'read-only-sp-id'
    principalType: 'ServicePrincipal'
    principalDisplayName: 'Read-Only Service'
    appRoleValue: 'Data.Read'
    description: 'Read-only data access'
  }
  {
    principalId: 'managers-group-id'
    principalType: 'Group'
    principalDisplayName: 'Managers Group'
    appRoleValue: 'Manager'
    description: 'Management level access'
  }
]

// Create role assignments for each principal
module roleAssignments_deploy 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = [for (assignment, i) in roleAssignments: {
  name: 'role-assignment-${i}'
  params: {
    appRoleId: 'role-id-for-${assignment.appRoleValue}' // You'll need to map these
    principalId: assignment.principalId
    resourceId: apiServicePrincipalId
    resourceDisplayName: 'Enterprise API - ${environment}'
    principalDisplayName: assignment.principalDisplayName
    principalType: assignment.principalType
    appRoleValue: assignment.appRoleValue
    environmentName: environment
  }
}]

output assignmentIds array = [for i in range(0, length(roleAssignments)): roleAssignments_deploy[i].outputs.id]
```

### Step 2: Deploy Multi-Role Setup

```bash
# Get all required IDs first
API_SP_ID=$(az ad sp list --filter "displayName eq 'Enterprise API'" --query "[0].id" -o tsv)
ADMIN_USER_ID=$(az ad user show --id "admin@contoso.com" --query "id" -o tsv)
GROUP_ID=$(az ad group show --group "Managers" --query "id" -o tsv)

# Deploy multiple role assignments
az deployment group create \
  --resource-group "rg-enterprise" \
  --template-file "multi-role-assignments.bicep" \
  --parameters apiServicePrincipalId="$API_SP_ID" environment="production" \
  --name "multi-role-deployment"
```

**🎉 Multi-principal role assignments deployed for enterprise access control!**

---

## 🛠️ Common Operations

### List App Role Assignments

```bash
# List assignments for a principal
az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/<principal-id>/appRoleAssignments" \
  --query "value[].{appRoleId:appRoleId,resourceDisplayName:resourceDisplayName,principalDisplayName:principalDisplayName}"

# List assignments for a resource (who has access)
az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/<resource-id>/appRoleAssignedTo" \
  --query "value[].{principalDisplayName:principalDisplayName,appRoleId:appRoleId}"
```

### Find App Roles

```bash
# List all app roles for an application
az ad sp show --id <service-principal-id> \
  --query "appRoles[].{id:id,value:value,displayName:displayName,description:description}" -o table

# Find specific app role ID
az ad sp show --id <service-principal-id> \
  --query "appRoles[?value=='Data.Read'].id" -o tsv
```

### Manage Assignments

```bash
# Check if assignment exists
az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/<principal-id>/appRoleAssignments" \
  --query "value[?appRoleId=='<role-id>' && resourceId=='<resource-id>'].id" -o tsv

# Remove assignment
az rest --method DELETE \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/<principal-id>/appRoleAssignments/<assignment-id>"
```

## 🔍 Troubleshooting

### Issue: App Role Not Found

**Error**: `AppRole with id '<role-id>' not found`

**Solution**: Verify the app role exists and get the correct ID:

```bash
# List all app roles for the resource application
az ad sp show --id <resource-sp-id> \
  --query "appRoles[].{id:id,value:value,displayName:displayName}" -o table

# Check if role is enabled
az ad sp show --id <resource-sp-id> \
  --query "appRoles[?value=='RoleName'].isEnabled" -o tsv
```

### Issue: Assignment Already Exists

**Error**: `Permission grant already exists`

**Solution**: Check existing assignments and update if needed:

```bash
# Find existing assignment
az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/<principal-id>/appRoleAssignments" \
  --query "value[?resourceId=='<resource-id>']" -o table

# If you need to change the role, delete and recreate
az rest --method DELETE \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/<principal-id>/appRoleAssignments/<assignment-id>"
```

### Issue: Principal Not Found

**Error**: `Principal with id '<principal-id>' not found`

**Solution**: Verify the principal exists and is the correct type:

```bash
# Check if service principal exists
az ad sp show --id <principal-id> --query "{id:id,displayName:displayName}"

# Check if user exists
az ad user show --id <principal-id> --query "{id:id,displayName:displayName}"

# Check if group exists
az ad group show --group <principal-id> --query "{id:id,displayName:displayName}"
```

### Issue: Insufficient Privileges

**Error**: `Insufficient privileges to complete the operation`

**Solution**: Verify you have the required permissions:

```bash
# Check your roles
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) \
  --query "[].roleDefinitionName" -o table
```

Ensure you have **Application Administrator** or **Global Administrator** role.

## 🔗 Quick Reference

### Principal Types

| Type | Description | Use Case |
|------|-------------|----------|
| `User` | Individual user account | Personal access, admin assignments |
| `ServicePrincipal` | Application identity | API-to-API access, automation |
| `Group` | Collection of users | Team access, department permissions |

### Common App Role Values

```bash
# Typical application roles
Admin                    # Full administrative access
Manager                  # Management level permissions
User                     # Standard user access
Data.Read               # Read-only data access
Data.ReadWrite          # Read and write data access
Data.Admin              # Data administrative access
```

### Essential Commands

```bash
# Get service principal ID by display name
az ad sp list --filter "displayName eq 'App Name'" --query "[0].id" -o tsv

# Get user object ID by email
az ad user show --id "user@domain.com" --query "id" -o tsv

# Get group object ID by name
az ad group show --group "Group Name" --query "id" -o tsv

# Get app role ID by value
az ad sp show --id <sp-id> --query "appRoles[?value=='RoleName'].id" -o tsv
```

## 🔗 Next Steps

- 📖 **[Full Documentation](README.md)** - Complete module reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Advanced assignment scenarios
- 🏢 **[Service Principals](../servicePrincipals/QUICKSTART.md)** - Create app identities
- 🔐 **[OAuth2 Permissions](../oauth2PermissionGrants/QUICKSTART.md)** - Delegate permissions
- 👥 **[Applications](../applications/QUICKSTART.md)** - Register applications with roles

## 💡 Pro Tips

1. **Use descriptive display names** - Makes assignments easier to identify and audit
2. **Document role purposes** - Clear descriptions help with access reviews
3. **Start with least privilege** - Assign minimal required roles, escalate as needed
4. **Group-based assignments** - Use groups for easier management of multiple users
5. **Environment-specific roles** - Different permissions for dev/staging/production
6. **Regular access reviews** - Audit and remove unused role assignments
7. **Monitor role usage** - Set up alerts for sensitive role assignments

---

**🔐 Your app role assignments are configured for secure access control!** 🚀

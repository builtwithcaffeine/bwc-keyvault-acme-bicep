# 🚀 Quick Start Guide

## Microsoft Graph Users Module

Get Azure AD user references configured for identity management in **under 2 minutes**!

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Azure AD permissions: **User Administrator** or **Global Administrator**
- Valid user accounts in Azure AD tenant

```bash
# Verify prerequisites
az ad signed-in-user show --query "displayName"
az bicep version
```

## 🎯 Option 1: Single User Reference (30 seconds)

### Step 1: Find Your User

```bash
# Find user by email
az ad user show --id "user@contoso.com" --query "{id:id,displayName:displayName,userPrincipalName:userPrincipalName}"
```

### Step 2: Create Parameter File

Create `quickstart-user.bicepparam`:

```bicep
using 'modules/microsoft-graph/users/main.bicep'

// Reference existing user by object ID
param id = '12345678-1234-1234-1234-123456789012' // User object ID from step 1
```

### Step 3: Deploy User Reference

```bash
# Deploy user reference
az deployment group create \
  --resource-group "rg-quickstart" \
  --template-file "modules/microsoft-graph/users/main.bicep" \
  --parameters "quickstart-user.bicepparam" \
  --name "quickstart-user-deployment"
```

**🎉 Done! User reference is available for other Bicep modules.**

---

## 🎯 Option 2: Team User References (1 minute)

### Step 1: Get Team Member IDs

```bash
# Get multiple users by email
az ad user list --filter "userPrincipalName in ('user1@contoso.com','user2@contoso.com','admin@contoso.com')" \
  --query "[].{id:id,displayName:displayName,userPrincipalName:userPrincipalName}" -o table
```

### Step 2: Create Team Parameter File

Create `team-users.bicepparam`:

```bicep
using 'team-users-template.bicep'

// Team member object IDs (from step 1)
param teamLeadId = '11111111-1111-1111-1111-111111111111'
param developerId = '22222222-2222-2222-2222-222222222222'
param adminId = '33333333-3333-3333-3333-333333333333'
```

### Step 3: Create Team Template

Create `team-users-template.bicep`:

```bicep
targetScope = 'resourceGroup'

param teamLeadId string
param developerId string  
param adminId string

// Team lead user reference
module teamLead 'modules/microsoft-graph/users/main.bicep' = {
  name: 'user-team-lead'
  params: {
    id: teamLeadId
  }
}

// Developer user reference
module developer 'modules/microsoft-graph/users/main.bicep' = {
  name: 'user-developer'
  params: {
    id: developerId
  }
}

// Admin user reference
module admin 'modules/microsoft-graph/users/main.bicep' = {
  name: 'user-admin'
  params: {
    id: adminId
  }
}

// Output user references for other modules
output teamLeadObjectId string = teamLead.outputs.id
output developerObjectId string = developer.outputs.id
output adminObjectId string = admin.outputs.id

output allUserIds array = [
  teamLead.outputs.id
  developer.outputs.id
  admin.outputs.id
]
```

### Step 4: Deploy Team References

```bash
az deployment group create \
  --resource-group "rg-team" \
  --template-file "team-users-template.bicep" \
  --parameters "team-users.bicepparam" \
  --name "team-users-deployment"
```

**🎉 Team user references configured for group assignments!**

---

## 🎯 Option 3: Enterprise User Management (2 minutes)

### Step 1: Create Enterprise Template

Create `enterprise-users.bicep`:

```bicep
targetScope = 'resourceGroup'

@description('List of user emails to reference')
param userEmails array

@description('Environment tag for the deployment')
param environment string = 'production'

// Create user references for each email
module userReferences 'modules/microsoft-graph/users/main.bicep' = [for (email, i) in userEmails: {
  name: 'user-ref-${i}'
  params: {
    id: email // Can use email or object ID
  }
}]

// Group security group with user references
module securityGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'enterprise-security-group'
  params: {
    displayName: 'Enterprise Users - ${environment}'
    mailNickname: 'enterprise-users-${toLower(environment)}'
    description: 'Security group for enterprise user access'
    groupTypes: []
    mailEnabled: false
    securityEnabled: true
    members: [for i in range(0, length(userEmails)): userReferences[i].outputs.id]
  }
}

output userObjectIds array = [for i in range(0, length(userEmails)): userReferences[i].outputs.id]
output securityGroupId string = securityGroup.outputs.id
```

### Step 2: Deploy Enterprise Setup

```bash
# Deploy enterprise user management
az deployment group create \
  --resource-group "rg-enterprise" \
  --template-file "enterprise-users.bicep" \
  --parameters userEmails='["manager@contoso.com","lead@contoso.com","admin@contoso.com"]' environment="production" \
  --name "enterprise-users-deployment"
```

**🎉 Enterprise user management with security group is ready!**

---

## 🛠️ Common Operations

### Find Users

```bash
# List all users
az ad user list --query "[].{displayName:displayName,userPrincipalName:userPrincipalName,id:id}" -o table

# Find user by display name
az ad user list --filter "startswith(displayName, 'John')" --query "[].{displayName:displayName,userPrincipalName:userPrincipalName,id:id}" -o table

# Find user by email
az ad user show --id "user@contoso.com" --query "{id:id,displayName:displayName,userPrincipalName:userPrincipalName}"

# Find users by department
az ad user list --filter "department eq 'Engineering'" --query "[].{displayName:displayName,userPrincipalName:userPrincipalName}" -o table
```

### User Information

```bash
# Get detailed user info
az ad user show --id <user-id> --query "{displayName:displayName,userPrincipalName:userPrincipalName,jobTitle:jobTitle,department:department,officeLocation:officeLocation}"

# Get user's group memberships
az ad user get-member-groups --id <user-id> --query "[].displayName" -o table

# Check if user exists
az ad user show --id "user@contoso.com" --query "id" -o tsv 2>/dev/null || echo "User not found"
```

### User Status and Properties

```bash
# Check user account status
az ad user show --id <user-id> --query "{accountEnabled:accountEnabled,userType:userType,signInActivity:signInActivity}"

# Get user's assigned licenses
az ad user show --id <user-id> --query "assignedLicenses[].skuId" -o table

# Get user's manager
az ad user show --id <user-id> --query "manager" -o table
```

## 🔍 Troubleshooting

### Issue: User Not Found

**Error**: `User not found` or `Request_ResourceNotFound`

**Solution**: Verify the user exists and you have the correct identifier:

```bash
# Search by partial name
az ad user list --filter "startswith(displayName, 'John')" --query "[].userPrincipalName" -o table

# Check if using correct domain
az ad user list --filter "endswith(userPrincipalName, '@contoso.com')" --query "[].userPrincipalName" -o table
```

### Issue: Permission Denied

**Error**: `Insufficient privileges to complete the operation`

**Solution**: Verify you have the required permissions:

```bash
# Check your roles
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) \
  --query "[].roleDefinitionName" -o table
```

Ensure you have **User Administrator**, **User Reader**, or **Global Administrator** role.

### Issue: Invalid User ID Format

**Error**: `Invalid GUID format`

**Solution**: Ensure you're using the correct object ID format:

```bash
# Get object ID from email
az ad user show --id "user@contoso.com" --query "id" -o tsv

# Validate GUID format (should be: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
echo "12345678-1234-1234-1234-123456789012" | grep -E '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
```

## 🔗 Quick Reference

### User Identifier Types

| Type | Format | Example | Use Case |
|------|--------|---------|----------|
| Object ID | GUID | `12345678-1234-1234-1234-123456789012` | Bicep modules, stable reference |
| User Principal Name | Email | `user@contoso.com` | CLI commands, user lookup |
| Display Name | String | `John Doe` | Search and identification |

### Essential Commands

```bash
# Get your own object ID
az ad signed-in-user show --query id -o tsv

# Convert email to object ID
az ad user show --id "user@domain.com" --query id -o tsv

# Get multiple users by emails
az ad user list --filter "userPrincipalName in ('user1@domain.com','user2@domain.com')" --query "[].{id:id,userPrincipalName:userPrincipalName}" -o table

# Check if user is guest
az ad user show --id <user-id> --query "userType" -o tsv
```

### Common Filters

```bash
# Active users only
az ad user list --filter "accountEnabled eq true"

# Guest users
az ad user list --filter "userType eq 'Guest'"

# Users by department
az ad user list --filter "department eq 'Engineering'"

# Users created in last 30 days
az ad user list --filter "createdDateTime ge $(date -d '30 days ago' -u +%Y-%m-%dT%H:%M:%SZ)"
```

## 🔗 Next Steps

- 📖 **[Full Documentation](README.md)** - Complete module reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Advanced user scenarios
- 👥 **[Groups Module](../groups/QUICKSTART.md)** - Add users to groups
- 🔐 **[App Role Assignments](../appRoleAssignedTo/QUICKSTART.md)** - Assign app permissions
- 🏢 **[Service Principals](../servicePrincipals/QUICKSTART.md)** - Application identities

## 💡 Pro Tips

1. **Use object IDs in Bicep** - More stable than emails which can change
2. **Cache user lookups** - Store object IDs to avoid repeated API calls
3. **Validate user existence** - Check users exist before referencing in other modules
4. **Use descriptive deployment names** - Include user context in deployment names
5. **Batch user operations** - Process multiple users in single deployments
6. **Monitor user changes** - Set up alerts for critical user account modifications

---

**👤 Your user references are ready for identity management!** 🚀
# 🚀 Quick Start Guide

## Microsoft Graph Groups Module

Get Azure AD groups configured for team collaboration in **under 3 minutes**!

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Azure AD permissions: **Groups Administrator** or **Global Administrator**
- Valid email domain for the tenant

```bash
# Verify prerequisites
az ad signed-in-user show --query "displayName"
az bicep version
```

## 🎯 Option 1: Basic Security Group (1 minute)

### Step 1: Create Parameter File

Create `quickstart-group.bicepparam`:

```bicep
using 'modules/microsoft-graph/groups/main.bicep'

// Basic security group
param displayName = 'Project Alpha Team'
param mailNickname = 'project-alpha'
param description = 'Security group for Project Alpha team members'
param groupTypes = [] // Security group (no Microsoft 365)
param mailEnabled = false
param securityEnabled = true
```

### Step 2: Deploy

```bash
# Deploy security group
az deployment group create \
  --resource-group "rg-quickstart" \
  --template-file "modules/microsoft-graph/groups/main.bicep" \
  --parameters "quickstart-group.bicepparam" \
  --name "quickstart-group-deployment"
```

### Step 3: Get Group Details

```bash
# Get group information
az deployment group show \
  --resource-group "rg-quickstart" \
  --name "quickstart-group-deployment" \
  --query "properties.outputs.{id:id.value,displayName:displayName.value,mail:mail.value}"
```

**🎉 Done! Your security group is ready for member assignments.**

---

## 🎯 Option 2: Microsoft 365 Group with Teams (2 minutes)

### Step 1: Create M365 Parameter File

Create `m365-group.bicepparam`:

```bicep
using 'modules/microsoft-graph/groups/main.bicep'

// Microsoft 365 group with Teams integration
param displayName = 'Marketing Team'
param mailNickname = 'marketing-team'
param description = 'Marketing team collaboration and communication hub'
param groupTypes = ['Unified'] // Microsoft 365 group
param mailEnabled = true
param securityEnabled = false
param visibility = 'Private'
param owners = [
  'manager@contoso.com'    // Team manager
  'admin@contoso.com'      // Admin owner
]
param members = [
  'user1@contoso.com'
  'user2@contoso.com'
  'contractor@contoso.com'
]
```

### Step 2: Deploy M365 Group

```bash
az deployment group create \
  --resource-group "rg-teams" \
  --template-file "modules/microsoft-graph/groups/main.bicep" \
  --parameters "m365-group.bicepparam" \
  --name "m365-group-deployment"
```

### Step 3: Enable Teams (Optional)

```bash
# Get the group ID from deployment output
GROUP_ID=$(az deployment group show \
  --resource-group "rg-teams" \
  --name "m365-group-deployment" \
  --query "properties.outputs.id.value" -o tsv)

# Enable Teams for the group (requires Microsoft Graph PowerShell)
Connect-MgGraph -Scopes "Team.Create"
New-MgTeam -GroupId $GROUP_ID
```

**🎉 Microsoft 365 group with Teams is ready for collaboration!**

---

## 🎯 Option 3: Multi-Type Group Deployment (3 minutes)

### Step 1: Create Multi-Group Template

Create `multi-groups.bicep`:

```bicep
targetScope = 'resourceGroup'

param projectName string
param environment string
param adminEmails array = []

// Project security groups
module projectSecurityGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'security-${projectName}-${environment}'
  params: {
    displayName: '${projectName} - Security (${environment})'
    mailNickname: 'sec-${toLower(projectName)}-${toLower(environment)}'
    description: 'Security group for ${projectName} project access control'
    groupTypes: []
    mailEnabled: false
    securityEnabled: true
    owners: adminEmails
  }
}

// Project collaboration group (M365)
module projectCollabGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'collab-${projectName}-${environment}'
  params: {
    displayName: '${projectName} - Team (${environment})'
    mailNickname: 'team-${toLower(projectName)}-${toLower(environment)}'
    description: 'Collaboration group for ${projectName} project team'
    groupTypes: ['Unified']
    mailEnabled: true
    securityEnabled: false
    visibility: 'Private'
    owners: adminEmails
  }
}

// Distribution list for notifications
module projectDistributionGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'dist-${projectName}-${environment}'
  params: {
    displayName: '${projectName} - Notifications (${environment})'
    mailNickname: 'notify-${toLower(projectName)}-${toLower(environment)}'
    description: 'Distribution list for ${projectName} project notifications'
    groupTypes: []
    mailEnabled: true
    securityEnabled: false
    owners: adminEmails
  }
}

output securityGroupId string = projectSecurityGroup.outputs.id
output collaborationGroupId string = projectCollabGroup.outputs.id
output distributionGroupId string = projectDistributionGroup.outputs.id
```

### Step 2: Deploy Multiple Groups

```bash
# Deploy all project groups
az deployment group create \
  --resource-group "rg-projects" \
  --template-file "multi-groups.bicep" \
  --parameters projectName="Phoenix" environment="Production" adminEmails='["admin@contoso.com","manager@contoso.com"]' \
  --name "phoenix-groups-deployment"
```

**🎉 Complete group structure for your project is ready!**

---

## 🛠️ Common Operations

### Manage Group Members

```bash
# List group members
az ad group member list --group <group-id> --query "[].displayName" -o table

# Add member to group
az ad group member add --group <group-id> --member-id <user-object-id>

# Remove member from group  
az ad group member remove --group <group-id> --member-id <user-object-id>

# Check if user is member
az ad group member check --group <group-id> --member-id <user-object-id>
```

### Manage Group Owners

```bash
# List group owners
az ad group owner list --group <group-id> --query "[].displayName" -o table

# Add owner to group
az ad group owner add --group <group-id> --owner-object-id <user-object-id>

# Remove owner from group
az ad group owner remove --group <group-id> --owner-object-id <user-object-id>
```

### Group Information

```bash
# Get all groups
az ad group list --query "[].{displayName:displayName,id:id,mailNickname:mailNickname}" -o table

# Get specific group
az ad group show --group <group-id> --query "{displayName:displayName,description:description,mailEnabled:mailEnabled,securityEnabled:securityEnabled}"

# Find group by display name
az ad group list --filter "displayName eq 'Project Alpha Team'" --query "[0].id" -o tsv
```

### Group Types and Properties

```bash
# List Microsoft 365 groups
az ad group list --filter "groupTypes/any(x:x eq 'Unified')" --query "[].displayName" -o table

# List security groups  
az ad group list --filter "securityEnabled eq true and not(groupTypes/any(x:x eq 'Unified'))" --query "[].displayName" -o table

# List mail-enabled groups
az ad group list --filter "mailEnabled eq true" --query "[].{displayName:displayName,mail:mail}" -o table
```

## 🔍 Troubleshooting

### Issue: Group Already Exists

**Error**: `Another object with the same value for property mailNickname already exists`

**Solution**: mailNickname must be unique. Check existing groups:

```bash
az ad group list --filter "mailNickname eq 'your-mail-nickname'" --query "[].displayName"
```

### Issue: Permission Denied

**Error**: `Insufficient privileges to complete the operation`

**Solution**: Verify you have the required permissions:

```bash
# Check your roles
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) \
  --query "[].roleDefinitionName" -o table
```

Ensure you have **Groups Administrator** or **Global Administrator** role.

### Issue: Invalid Owner/Member

**Error**: `One or more added object references already exist`

**Solution**: User might already be an owner/member, or object ID is incorrect:

```bash
# Get user object ID
az ad user show --id "user@contoso.com" --query id -o tsv

# Check current members
az ad group member list --group <group-id> --query "[].userPrincipalName" -o table
```

### Issue: Cannot Create Microsoft 365 Group

**Error**: `The mailNickname is invalid`

**Solution**: Ensure mailNickname follows naming rules:

- Only letters, numbers, and hyphens
- No spaces or special characters
- Must be unique across the tenant

```bash
# Check if mailNickname is available
az ad group list --filter "mailNickname eq 'your-nickname'" --query "length([])
```

## 🔗 Quick Reference

### Group Types

| Type | groupTypes | mailEnabled | securityEnabled | Use Case |
|------|------------|-------------|-----------------|----------|
| Security | `[]` | `false` | `true` | Access control, permissions |
| Distribution | `[]` | `true` | `false` | Email distribution lists |
| Microsoft 365 | `['Unified']` | `true` | `false` | Teams, SharePoint, collaboration |
| Mail-enabled Security | `[]` | `true` | `true` | Security with email capabilities |

### Essential Commands

```bash
# Get your object ID (for owner assignment)
az ad signed-in-user show --query id -o tsv

# Get group by name
az ad group list --filter "displayName eq 'Group Name'" --query "[0].{id:id,mailNickname:mailNickname}"

# Get user object ID by email
az ad user show --id "user@domain.com" --query id -o tsv
```

## 🔗 Next Steps

- 📖 **[Full Documentation](README.md)** - Complete module reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Advanced usage scenarios
- 👤 **[Users Module](../users/QUICKSTART.md)** - User management
- 🔐 **[App Role Assignments](../appRoleAssignedTo/QUICKSTART.md)** - Assign app roles
- 🏢 **[Service Principals](../servicePrincipals/QUICKSTART.md)** - Application identities

## 💡 Pro Tips

1. **Use descriptive mailNicknames** - Choose clear, project-based naming conventions
2. **Plan group hierarchy** - Use consistent naming for related groups (project-team, project-security)
3. **Assign multiple owners** - Always have backup owners for group management
4. **Consider group types carefully** - Security groups for access, M365 groups for collaboration
5. **Monitor group membership** - Regular audits for security and compliance
6. **Use nested groups** - Add security groups to M365 groups for easier management

---

**🎉 Your Azure AD groups are ready for team collaboration!** 🚀
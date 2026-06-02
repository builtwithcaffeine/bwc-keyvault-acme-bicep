# 🚀 Quick Start Guide

## Microsoft Graph Groups Module

Create Microsoft Entra groups in **under 3 minutes**.

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Microsoft Entra permissions for group creation/management
- Bicep CLI available (`az bicep version`)

## 🎯 Option 1: Basic security group (1 minute)

### Step 1: Create parameter file

Create `quickstart-group.bicepparam`:

```bicep
using 'modules/microsoft-graph/groups/main.bicep'

param displayName = 'Contoso IT Security Team'
param groupName = 'contoso-it-security-team'
param mailNickname = 'contosoitsecurity'
param groupDescription = 'Security group for IT team members'
param securityEnabled = true
param mailEnabled = false
```

### Step 2: Deploy

```bash
az deployment group create \
  --resource-group "rg-quickstart" \
  --template-file "modules/microsoft-graph/groups/main.bicep" \
  --parameters "quickstart-group.bicepparam" \
  --name "quickstart-group-deployment"
```

### Step 3: Verify outputs

```bash
az deployment group show \
  --resource-group "rg-quickstart" \
  --name "quickstart-group-deployment" \
  --query "properties.outputs"
```

**🎉 Done! Your security group is ready.**

---

## 🎯 Option 2: Microsoft 365 group (2 minutes)

Create `m365-group.bicepparam`:

```bicep
using 'modules/microsoft-graph/groups/main.bicep'

param displayName = 'Contoso Marketing Team'
param groupName = 'contoso-marketing-team'
param mailNickname = 'contosomarketing'
param groupDescription = 'Unified group for marketing collaboration'
param mailEnabled = true
param securityEnabled = true
param groupTypes = [
  'Unified'
]
param visibility = 'Private'
param preferredLanguage = 'en-US'
param preferredDataLocation = 'EUR'
param theme = 'Blue'
```

Deploy with the same command pattern as Option 1.

---

## 🎯 Option 3: Dynamic membership group (3 minutes)

Create `dynamic-group.bicepparam`:

```bicep
using 'modules/microsoft-graph/groups/main.bicep'

param displayName = 'Contoso Enabled Users'
param groupName = 'contoso-enabled-users'
param mailNickname = 'contosoenabledusers'
param securityEnabled = true
param mailEnabled = false
param membershipRule = '(user.accountEnabled -eq true)'
param membershipRuleProcessingState = 'On'
```

Deploy with the same command pattern as Option 1.

---

## 🛠️ Common operations

```bash
# List groups
az ad group list --query "[].{id:id,displayName:displayName,mailNickname:mailNickname}" -o table

# Show one group
az ad group show --group <group-id>
```

## 🔍 Notes

- `visibility` is relevant when `groupTypes` contains `Unified`.
- For role-assignable groups, set `isAssignableToRole = true` and ensure tenant support/permissions.
- Use Entra object IDs in `ownerIds` and `memberIds` when assigning at creation time.

## 🔗 Next Steps

- 📖 **[Full Documentation](README.md)** - Complete module reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Additional scenarios
- 👤 **[Users Module](../users/QUICKSTART.md)** - Resolve user IDs for membership
- 🔐 **[App Role Assignments](../appRoleAssignedTo/QUICKSTART.md)** - Role-based access setup

# 🚀 Quick Start Guide

## Microsoft Graph Applications Module

Get up and running with Azure AD application management in **under 5 minutes**!

## ⚡ Prerequisites

- Azure CLI 2.50+ or Azure PowerShell 10.0+
- Azure AD permissions: **Application Administrator** or **Global Administrator**
- Microsoft Graph Bicep extension installed

```bash
# Install Azure CLI extension
az extension add --name bicep

# Verify Microsoft Graph Bicep support
az bicep version
```

## 🎯 Option 1: Basic Application (2 minutes)

### Step 1: Create Parameter File

Create `quickstart.bicepparam`:

```bicep
using 'modules/microsoft-graph/applications/main.bicep'

// Basic enterprise application
param displayName = 'QuickStart-MyApp'
param uniqueName = 'quickstart-myapp'
param webRedirectUris = ['https://myapp.contoso.com/auth/callback']
param requiredResourceAccess = [
  {
    resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
    resourceAccess: [
      {
        id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
        type: 'Scope'
      }
    ]
  }
]
param tags = ['Environment:Production', 'Owner:Platform-Team']
```

### Step 2: Deploy

```bash
# Deploy application
az deployment group create \
  --resource-group "rg-quickstart" \
  --template-file "modules/microsoft-graph/applications/main.bicep" \
  --parameters "quickstart.bicepparam" \
  --name "quickstart-app-deployment"
```

### Step 3: Get Results

```bash
# Get application details
az deployment group show \
  --resource-group "rg-quickstart" \
  --name "quickstart-app-deployment" \
  --query "properties.outputs"
```

**🎉 Done! Your application is ready.**

---

## 🎯 Option 2: API Application with Roles (3 minutes)

### Step 1: Create Advanced Parameter File

Create `api-quickstart.bicepparam`:

```bicep
using 'modules/microsoft-graph/applications/main.bicep'

// API application with app roles
param displayName = 'QuickStart-API'
param uniqueName = 'quickstart-api'
param identifierUris = ['api://quickstart-api']
param appRoles = [
  {
    id: 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    allowedMemberTypes: ['Application']
    description: 'Read access to application data'
    displayName: 'Data Reader'
    value: 'Data.Read'
    isEnabled: true
  }
  {
    id: 'b2c3d4e5-f6g7-8901-2345-678901bcdefg'
    allowedMemberTypes: ['User']
    description: 'Administrator access to application'
    displayName: 'Administrator'
    value: 'Admin'
    isEnabled: true
  }
]
param oauth2PermissionScopes = [
  {
    id: 'c3d4e5f6-g7h8-9012-3456-789012cdefgh'
    adminConsentDescription: 'Access user data'
    adminConsentDisplayName: 'Access user data'
    userConsentDescription: 'Allow access to your data'
    userConsentDisplayName: 'Access your data'
    value: 'user.read'
    type: 'User'
    isEnabled: true
  }
]
param tags = ['Type:API', 'Environment:Production']
```

### Step 2: Deploy

```bash
az deployment group create \
  --resource-group "rg-quickstart" \
  --template-file "modules/microsoft-graph/applications/main.bicep" \
  --parameters "api-quickstart.bicepparam" \
  --name "quickstart-api-deployment"
```

**🎉 Your API application with roles is ready!**

---

## 🎯 Option 3: Complete Enterprise Setup (5 minutes)

### Step 1: Multi-Environment Deployment

Create `enterprise-quickstart.bicepparam`:

```bicep
using 'modules/microsoft-graph/applications/main.bicep'

// Enterprise application with full configuration
param displayName = 'Enterprise-QuickStart'
param uniqueName = 'enterprise-quickstart'
param webRedirectUris = [
  'https://quickstart.contoso.com/auth/callback'
  'https://staging-quickstart.contoso.com/auth/callback'
]
param spaRedirectUris = ['https://quickstart.contoso.com/spa-callback']
param publicClientRedirectUris = ['myapp://auth']
param logoutUrl = 'https://quickstart.contoso.com/logout'
param identifierUris = ['api://enterprise-quickstart']

// Microsoft Graph + Custom API permissions
param requiredResourceAccess = [
  {
    resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
    resourceAccess: [
      {
        id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
        type: 'Scope'
      }
      {
        id: 'b340eb25-3456-403f-be2f-af7a0d370277' // User.ReadBasic.All
        type: 'Scope'
      }
    ]
  }
]

// Application roles for RBAC
param appRoles = [
  {
    id: 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    allowedMemberTypes: ['User', 'Application']
    description: 'Full administrative access'
    displayName: 'Administrator'
    value: 'Admin'
    isEnabled: true
  }
  {
    id: 'b2c3d4e5-f6g7-8901-2345-678901bcdefg'
    allowedMemberTypes: ['User']
    description: 'Read-only access to data'
    displayName: 'Reader'
    value: 'Reader'
    isEnabled: true
  }
]

// Custom OAuth2 permissions
param oauth2PermissionScopes = [
  {
    id: 'c3d4e5f6-g7h8-9012-3456-789012cdefgh'
    adminConsentDescription: 'Read user profile data'
    adminConsentDisplayName: 'Read user profiles'
    userConsentDescription: 'Read your profile data'
    userConsentDisplayName: 'Read your profile'
    value: 'profile.read'
    type: 'User'
    isEnabled: true
  }
]

param tags = [
  'Environment:Production'
  'Application:Enterprise'
  'Owner:Platform-Team'
  'CostCenter:IT-001'
]
```

### Step 2: Deploy Enterprise Application

```bash
az deployment group create \
  --resource-group "rg-enterprise" \
  --template-file "modules/microsoft-graph/applications/main.bicep" \
  --parameters "enterprise-quickstart.bicepparam" \
  --name "enterprise-quickstart-deployment"
```

### Step 3: Verify Deployment

```bash
# Get comprehensive application details
az deployment group show \
  --resource-group "rg-enterprise" \
  --name "enterprise-quickstart-deployment" \
  --query "properties.outputs" \
  --output table

# Verify in Azure Portal
echo "🔗 Check your application at: https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps"
```

**🎉 Enterprise application deployment complete!**

---

## 🛠️ Common Commands

### Get Application Information
```bash
# List all applications
az ad app list --query "[].{displayName:displayName,appId:appId}" --output table

# Get specific application details
az ad app show --id <app-id> --query "{displayName:displayName,appId:appId,objectId:id}"
```

### Update Application
```bash
# Update redirect URIs
az ad app update --id <app-id> --web-redirect-uris "https://newuri.com/callback"

# Add identifier URI
az ad app update --id <app-id> --identifier-uris "api://myapp"
```

### Delete Application (Cleanup)
```bash
# Delete application
az ad app delete --id <app-id>
```

## 🔍 Troubleshooting

### Issue: Permission Denied
```bash
# Check your permissions
az ad signed-in-user show --query "{displayName:displayName,userPrincipalName:userPrincipalName}"

# List your role assignments
az role assignment list --assignee <your-object-id> --query "[].roleDefinitionName"
```

**Solution**: Ensure you have **Application Administrator** or **Global Administrator** role.

### Issue: Duplicate Application Name
**Error**: `Another object with the same value for property displayName already exists`

**Solution**: Use a unique `displayName` and `uniqueName` in your parameters.

### Issue: Invalid Redirect URI
**Error**: `The reply URL specified in the request does not match`

**Solution**: Ensure redirect URIs use HTTPS and follow [Azure AD URI requirements](https://docs.microsoft.com/en-us/azure/active-directory/develop/reply-url).

## 🔗 Next Steps

- 📖 **[Full Documentation](README.md)** - Complete module reference
- 🧪 **[Test Examples](test/main.test.bicep)** - Advanced usage scenarios  
- 🏗️ **[Service Principals](../servicePrincipals/QUICKSTART.md)** - Create service principals
- 🔐 **[Federated Identity](applications/federatedIdentityCredentials/QUICKSTART.md)** - OIDC authentication

## 💡 Pro Tips

1. **Use descriptive names** - Include environment and purpose in application names
2. **Tag everything** - Use consistent tagging for cost management and organization
3. **Test permissions** - Verify API permissions work as expected before production
4. **Monitor applications** - Set up alerts for application usage and errors
5. **Regular cleanup** - Remove unused applications to maintain security

---

**⚡ You're ready to build enterprise Azure AD applications!** 🚀
# Microsoft Graph Bicep Modules

This collection of Bicep modules provides comprehensive Azure AD (Entra ID) resource management using the Microsoft Graph Bicep extension v1.0. These modules enable Infrastructure as Code (IaC) for Azure Active Directory resources.

## 📋 Overview

The Microsoft Graph Bicep modules in this collection allow you to declaratively manage Azure AD resources including applications, service principals, groups, users, and permissions. All modules are built using the official [Microsoft Graph Bicep v1.0 reference](https://learn.microsoft.com/en-us/graph/templates/bicep/reference/overview?view=graph-bicep-1.0).

## 🚀 Prerequisites

Before using these modules, ensure you have:

- **Azure CLI** or **Azure PowerShell** installed
- **Bicep CLI** version 0.4.x or later
- **Microsoft Graph Bicep Extension** enabled
- **Required Azure AD permissions** for the resources you want to manage

### Required Permissions

The deployment principal (user or service principal) needs appropriate Microsoft Graph permissions:

- **Application.ReadWrite.All** - For managing applications and service principals
- **Group.ReadWrite.All** - For managing groups
- **User.Read.All** - For reading user information
- **AppRoleAssignment.ReadWrite.All** - For managing app role assignments
- **DelegatedPermissionGrant.ReadWrite.All** - For managing OAuth2 permission grants

## 📁 Module Structure

```text
modules/microsoft-graph/
├── applications/                    # Azure AD Application registrations
├── appRoleAssignedTo/              # App role assignments
├── federatedIdentityCredentials/    # Federated identity credentials for applications
├── groups/                         # Azure AD Groups
├── oauth2PermissionGrants/         # OAuth2 permission grants (delegated permissions)
├── servicePrincipals/              # Service principals
└── users/                          # User references
```

## 🔧 Available Modules

### 1. Applications (`applications/`)

Creates and configures Azure AD application registrations.

**Key Features:**

- Application registration with custom settings
- Web, SPA, and public client configurations
- API permissions and app roles
- Authentication behaviors and optional claims
- Owner assignments

**Usage:**

```bicep
module appRegistration 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'my-app-registration'
  params: {
    displayName: 'My Application'
    appName: 'my-app-001'
    signInAudience: 'AzureADMyOrg'
    webRedirectUris: ['https://localhost:3000/auth/callback']
    requiredResourceAccess: [
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
  }
}
```

### 2. Service Principals (`servicePrincipals/`)
Creates and manages service principals for applications.

**Key Features:**
- Service principal creation for existing applications
- App role assignment requirements
- Tag and note management
- Key and password credentials
- Owner assignments

**Usage:**
```bicep
module servicePrincipal 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'my-service-principal'
  params: {
    appId: appRegistration.outputs.applicationId
    displayName: 'My Application Service Principal'
    appRoleAssignmentRequired: true
    tags: ['Production', 'WebApp']
  }
}
```

### 3. Groups (`groups/`)
Creates and manages Azure AD groups.

**Key Features:**
- Security and Microsoft 365 groups
- Dynamic membership rules
- Group owners and members
- Mail-enabled groups
- Role-assignable groups

**Usage:**
```bicep
module securityGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'app-users-group'
  params: {
    displayName: 'Application Users'
    groupName: 'app-users-001'
    mailNickname: 'appusers001'
    groupDescription: 'Users with access to the application'
    securityEnabled: true
    mailEnabled: false
    ownerIds: ['00000000-0000-0000-0000-000000000000']
    memberIds: ['11111111-1111-1111-1111-111111111111']
  }
}
```

### 4. App Role Assignments (`appRoleAssignedTo/`)
Manages app role assignments to users, groups, or service principals.

**Usage:**
```bicep
module roleAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'assign-app-role'
  params: {
    principalId: securityGroup.outputs.groupId
    principalType: 'Group'
    resourceId: servicePrincipal.outputs.servicePrincipalId
    appRoleId: '00000000-0000-0000-0000-000000000000' // Default access role
  }
}
```

### 5. OAuth2 Permission Grants (`oauth2PermissionGrants/`)
Manages delegated permission grants for applications.

**Usage:**
```bicep
module permissionGrant 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'grant-permissions'
  params: {
    clientId: servicePrincipal.outputs.servicePrincipalId
    consentType: 'AllPrincipals'
    resourceId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
    scope: 'User.Read'
  }
}
```

### 6. Federated Identity Credentials (`federatedIdentityCredentials/`)
Configures federated identity credentials for applications (useful for GitHub Actions, etc.).

**Usage:**
```bicep
module federatedCredential 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'github-actions-credential'
  params: {
    applicationId: appRegistration.outputs.objectId
    name: 'github-actions-main'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:myorg/myrepo:ref:refs/heads/main'
    audiences: ['api://AzureADTokenExchange']
    description: 'GitHub Actions credential for main branch'
  }
}
```

### 7. Users (`users/`)
References existing Azure AD users for use in other modules.

**Usage:**
```bicep
module userReference 'modules/microsoft-graph/users/main.bicep' = {
  name: 'get-user'
  params: {
    userPrincipalName: 'user@contoso.com'
  }
}
```

## 📝 Common Usage Patterns

### Complete Application Setup
```bicep
// 1. Create application registration
module app 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'my-application'
  params: {
    displayName: 'My Web Application'
    appName: 'my-web-app-001'
    signInAudience: 'AzureADMyOrg'
    webRedirectUris: ['https://myapp.contoso.com/auth/callback']
  }
}

// 2. Create service principal
module sp 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'my-service-principal'
  params: {
    appId: app.outputs.applicationId
    appRoleAssignmentRequired: true
  }
}

// 3. Create security group
module group 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'app-users'
  params: {
    displayName: 'My App Users'
    groupName: 'my-app-users-001'
    mailNickname: 'myappusers001'
    securityEnabled: true
  }
}

// 4. Assign group to application
module assignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'assign-group'
  params: {
    principalId: group.outputs.groupId
    principalType: 'Group'
    resourceId: sp.outputs.servicePrincipalId
    appRoleId: '00000000-0000-0000-0000-000000000000'
  }
}
```

## 🔒 Security Considerations

1. **Least Privilege**: Only grant the minimum required permissions
2. **Credential Management**: Use Azure Key Vault for storing sensitive credentials
3. **Service Principal Authentication**: Prefer managed identities where possible
4. **Regular Reviews**: Periodically review and clean up unused applications and permissions
5. **Audit Logging**: Enable Azure AD audit logs for compliance

## 🐛 Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure the deployment principal has sufficient Graph API permissions
2. **Schema Validation**: Some properties require specific formats (e.g., GUIDs, base64 strings)
3. **Duplicate Names**: Application names and group names must be unique within the tenant
4. **API Limits**: Be aware of Microsoft Graph throttling limits for bulk operations

### Error Examples

```bash
# Permission denied
Error: Insufficient privileges to complete the operation

# Solution: Grant Application.ReadWrite.All permission to deployment principal

# Invalid schema
Error: Property 'verifiedPublisher' has invalid schema

# Solution: Use null or omit optional properties when not needed
```

## 📚 References

- [Microsoft Graph Bicep v1.0 Reference](https://learn.microsoft.com/en-us/graph/templates/bicep/reference/overview?view=graph-bicep-1.0)
- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/)
- [Azure AD Application Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

## 🤝 Contributing

When contributing to these modules:

1. Follow the existing code structure and naming conventions
2. Include comprehensive parameter documentation
3. Add appropriate outputs for resource references
4. Test with minimal required permissions
5. Update this README with any new modules or significant changes

## 📄 License

These modules are provided under the same license as your project. Please ensure compliance with Microsoft Graph API terms of service.
# Microsoft Graph Application Module

This Bicep module creates and configures comprehensive Azure AD application registrations using the Microsoft Graph Bicep extension v1.0. It provides enterprise-ready functionality for managing application identities with extensive configuration options.

## 📋 Overview

This module provides a complete, enterprise-ready solution for creating Azure AD applications with extensive configuration options while following Bicep best practices. It supports all major application types including web apps, SPAs, mobile/desktop apps, and APIs based on the [Microsoft Graph applications resource type](https://learn.microsoft.com/en-us/graph/templates/bicep/reference/applications?view=graph-bicep-1.0).

## ✨ Features

- ✅ **Comprehensive Configuration**: Supports all Microsoft Graph application properties
- ✅ **Multi-Platform Support**: Web, SPA, mobile/desktop, and API applications
- ✅ **Security Features**: Authentication behaviors, parental controls, signature verification
- ✅ **Enterprise Ready**: Verified publisher, service management, token encryption
- ✅ **Developer Friendly**: Simplified parameter interface with smart defaults
- ✅ **Flexible Authentication**: Multiple sign-in audiences and redirect URI types
- ✅ **API Management**: OAuth2 scopes, pre-authorized applications, app roles
- ✅ **Rich Metadata**: Application info URLs, logos, tags, and notes
- ✅ **Credential Management**: Key and password credentials support
- ✅ **Access Control**: Owner management and permissions configuration

## 🚀 Prerequisites

Before using this module, ensure you have:

- **Azure CLI** or **Azure PowerShell** with Bicep CLI installed
- **Microsoft Graph Bicep Extension** configured in your project
- **Required permissions**: `Application.ReadWrite.All` or `Application.ReadWrite.OwnedBy`

### Permission Requirements

| Operation | Delegated (work/school) | Delegated (personal) | Application |
|-----------|------------------------|---------------------|-------------|
| Create/Update | Application.ReadWrite.All | Application.ReadWrite.All | Application.ReadWrite.OwnedBy, Application.ReadWrite.All |
| Read existing | Application.Read.All | Application.Read.All | Application.Read.All |

## 📖 Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `displayName` | string | Display name for the application (max 256 characters) |
| `uniqueName` | string | Immutable unique identifier for the application |

### Core Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `description` | string | `''` | Free text description of the application (max 1024 characters) |
| `signInAudience` | string | `'AzureADMyOrg'` | Microsoft accounts supported: `AzureADMyOrg`, `AzureADMultipleOrgs`, `AzureADandPersonalMicrosoftAccount`, `PersonalMicrosoftAccount` |
| `isFallbackPublicClient` | bool | `false` | Whether this is a fallback public client (mobile/desktop) |
| `isDeviceOnlyAuthSupported` | bool | `false` | Whether device-only authentication is supported |
| `groupMembershipClaims` | string | `null` | Groups claim configuration: `None`, `SecurityGroup`, `All` |

### Web Application Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `webRedirectUris` | array | `[]` | Web application redirect URIs for sign-in |
| `homePageUrl` | string | `''` | Home page or landing page URL |
| `logoutUrl` | string | `''` | Logout URL for front-channel, back-channel, or SAML logout |
| `enableIdTokenIssuance` | bool | `false` | Enable ID token issuance via OAuth 2.0 implicit flow |
| `enableAccessTokenIssuance` | bool | `false` | Enable access token issuance via OAuth 2.0 implicit flow |

### Single-Page Application (SPA) Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `spaRedirectUris` | array | `[]` | SPA redirect URIs for authorization codes and access tokens |

### Public Client (Mobile/Desktop) Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `publicClientRedirectUris` | array | `[]` | Mobile/desktop redirect URIs (e.g., `msauth.{BUNDLEID}://auth` for iOS/macOS) |

### API Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `identifierUris` | array | `[]` | App ID URIs - globally unique identifiers for the API |
| `requestedAccessTokenVersion` | int | `2` | Access token version (1 or 2) |
| `oauth2PermissionScopes` | array | `[]` | Delegated permissions (OAuth2 scopes) exposed by the API |
| `preAuthorizedApplications` | array | `[]` | Client applications pre-authorized to access the API |
| `acceptMappedClaims` | bool | `false` | Allow claims mapping without custom signing key |

### App Roles Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `appRoles` | array | `[]` | Application roles for users, groups, or other applications |

**App Role Object Schema:**
```bicep
{
  id: 'string'                    // GUID identifier
  displayName: 'string'           // Display name
  description: 'string'           // Role description
  value: 'string'                 // Role value (max 120 chars)
  allowedMemberTypes: ['User']    // ['User'], ['Application'], or both
  isEnabled: bool                 // Whether role is enabled
}
```

### API Permissions Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `requiredResourceAccess` | array | `[]` | API permissions required by the application |

**Required Resource Access Schema:**
```bicep
{
  resourceAppId: 'string'         // Target API's app ID (e.g., MS Graph: '00000003-0000-0000-c000-000000000000')
  resourceAccess: [
    {
      id: 'string'                // Permission ID
      type: 'Scope'               // 'Scope' for delegated, 'Role' for application permissions
    }
  ]
}
```

### Security & Authentication

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `blockAzureADGraphAccess` | bool | `false` | Block access to Azure AD Graph API |
| `removeUnverifiedEmailClaim` | bool | `false` | Remove unverified email claims |
| `requireClientServicePrincipal` | bool | `false` | Require client service principal |
| `isSignedRequestRequired` | bool | `false` | Require signed authentication requests |
| `allowedWeakAlgorithms` | string | `null` | Weak algorithms allowed for signatures |

### Credential Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `keyCredentials` | array | `[]` | X.509 certificate credentials |
| `passwordCredentials` | array | `[]` | Password/secret credentials |
| `tokenEncryptionKeyId` | string | `''` | Key ID for token encryption |

### Application Information

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `marketingUrl` | string | `''` | Link to application's marketing page |
| `privacyStatementUrl` | string | `''` | Link to privacy statement |
| `supportUrl` | string | `''` | Link to support page |
| `termsOfServiceUrl` | string | `''` | Link to terms of service |
| `logo` | string | `''` | Base64-encoded logo data |

### Metadata & Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tags` | array | `[]` | Custom strings for categorization |
| `notes` | string | `''` | Notes relevant for application management |
| `serviceManagementReference` | string | `''` | Reference to service/asset management database |
| `ownerIds` | array | `[]` | Object IDs of application owners |

### Optional Claims Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `optionalClaims` | object | `{}` | Optional claims for access tokens, ID tokens, and SAML tokens |

### Parental Controls

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `legalAgeGroupRule` | string | `'Allow'` | Legal age group rule: `Allow`, `RequireConsentForPrivacyServices`, `RequireConsentForMinors`, `RequireConsentForKids`, `BlockMinors` |
| `countriesBlockedForMinors` | array | `[]` | ISO country codes where access is blocked for minors |

## 📤 Outputs

| Output | Type | Description |
|--------|------|-------------|
| `resourceId` | string | The resource ID of the application |
| `applicationId` | string | The application (client) ID |
| `objectId` | string | The object ID of the application |
| `displayName` | string | The display name of the application |
| `uniqueName` | string | The unique name of the application |
| `signInAudience` | string | The sign-in audience of the application |
| `identifierUris` | array | The application identifier URIs |
| `webConfiguration` | object | Web configuration including redirect URIs and homepage |
| `spaConfiguration` | object | SPA configuration including redirect URIs |
| `publicClientConfiguration` | object | Public client configuration including redirect URIs |
| `apiConfiguration` | object | API configuration including OAuth2 permissions |

## 💡 Usage Examples

### Basic Web Application

```bicep
module webApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'myWebApp'
  params: {
    displayName: 'My Web Application'
    uniqueName: 'my-web-app-001'
    description: 'A sample web application for demonstrations'
    signInAudience: 'AzureADMyOrg'
    
    // Web configuration
    webRedirectUris: [
      'https://myapp.azurewebsites.net/signin-oidc'
      'https://localhost:5001/signin-oidc'
    ]
    homePageUrl: 'https://myapp.azurewebsites.net'
    logoutUrl: 'https://myapp.azurewebsites.net/signout-oidc'
    
    // Token configuration
    enableIdTokenIssuance: true
    requestedAccessTokenVersion: 2
    
    // Required permissions
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
    
    // Application info
    marketingUrl: 'https://mycompany.com/products/myapp'
    privacyStatementUrl: 'https://mycompany.com/privacy'
    supportUrl: 'https://support.mycompany.com'
    termsOfServiceUrl: 'https://mycompany.com/terms'
    
    // Metadata
    tags: ['web-app', 'production', 'public-facing']
    notes: 'Main customer-facing web application'
  }
}
```

### Single-Page Application (SPA)

```bicep
module spaApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'mySpaApp'
  params: {
    displayName: 'My React SPA'
    uniqueName: 'my-react-spa-001'
    description: 'React single-page application'
    signInAudience: 'AzureADMyOrg'
    
    // SPA configuration
    spaRedirectUris: [
      'https://myspa.azurewebsites.net/auth/callback'
      'http://localhost:3000/auth/callback'
    ]
    
    // Token configuration for SPA
    requestedAccessTokenVersion: 2
    
    // API permissions for SPA
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '37f7f235-527c-4136-accd-4a02d197296e' // User.ReadBasic.All
            type: 'Scope'
          }
        ]
      }
    ]
    
    tags: ['spa', 'react', 'frontend']
  }
}
```

### API Application with Custom Scopes

```bicep
module apiApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'myApiApp'
  params: {
    displayName: 'My Web API'
    uniqueName: 'my-web-api-001'
    description: 'Backend API for business operations'
    signInAudience: 'AzureADMyOrg'
    
    // API identifier
    identifierUris: ['api://my-web-api-001']
    
    // Expose OAuth2 scopes
    oauth2PermissionScopes: [
      {
        id: '12345678-1234-1234-1234-123456789012'
        adminConsentDescription: 'Allow the application to read user data'
        adminConsentDisplayName: 'Read user data'
        userConsentDescription: 'Allow the application to read your data'
        userConsentDisplayName: 'Read your data'
        value: 'user.read'
        type: 'User'
        isEnabled: true
      }
      {
        id: '87654321-4321-4321-4321-210987654321'
        adminConsentDescription: 'Allow the application to write user data'
        adminConsentDisplayName: 'Write user data'
        userConsentDescription: 'Allow the application to write your data'
        userConsentDisplayName: 'Write your data'
        value: 'user.write'
        type: 'User'
        isEnabled: true
      }
    ]
    
    // Define app roles
    appRoles: [
      {
        id: 'abcdef12-3456-7890-abcd-ef1234567890'
        displayName: 'Admin'
        description: 'Administrator role with full access'
        value: 'Admin'
        allowedMemberTypes: ['User']
        isEnabled: true
      }
      {
        id: 'fedcba98-7654-3210-fedc-ba9876543210'
        displayName: 'Reader'
        description: 'Read-only access to the API'
        value: 'Reader'
        allowedMemberTypes: ['User', 'Application']
        isEnabled: true
      }
    ]
    
    // Token version for API
    requestedAccessTokenVersion: 2
    acceptMappedClaims: false
    
    tags: ['api', 'backend', 'business-logic']
  }
}
```

### Mobile Application (Public Client)

```bicep
module mobileApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'myMobileApp'
  params: {
    displayName: 'My Mobile App'
    uniqueName: 'my-mobile-app-001'
    description: 'iOS and Android mobile application'
    signInAudience: 'AzureADMyOrg'
    
    // Public client configuration
    isFallbackPublicClient: true
    publicClientRedirectUris: [
      'msauth.com.mycompany.mymobileapp://auth'  // iOS
      'msauth://com.mycompany.mymobileapp/signature'  // Android
    ]
    
    // Required permissions for mobile
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '37f7f235-527c-4136-accd-4a02d197296e' // User.ReadBasic.All
            type: 'Scope'
          }
        ]
      }
    ]
    
    tags: ['mobile', 'ios', 'android', 'public-client']
  }
}
```

### Enterprise Application with Advanced Security

```bicep
module enterpriseApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'myEnterpriseApp'
  params: {
    displayName: 'Enterprise Business App'
    uniqueName: 'enterprise-business-app-001'
    description: 'Critical business application with enhanced security'
    signInAudience: 'AzureADMyOrg'
    
    // Web configuration
    webRedirectUris: [
      'https://enterprise.contoso.com/signin-oidc'
    ]
    homePageUrl: 'https://enterprise.contoso.com'
    logoutUrl: 'https://enterprise.contoso.com/signout-oidc'
    
    // Enhanced security settings
    blockAzureADGraphAccess: true
    removeUnverifiedEmailClaim: true
    requireClientServicePrincipal: true
    isSignedRequestRequired: true
    
    // Group membership claims
    groupMembershipClaims: 'SecurityGroup'
    
    // Required permissions with application permissions
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '19dbc75e-c2e2-444c-a770-ec69d8559fc7' // Directory.ReadWrite.All
            type: 'Role'
          }
        ]
      }
    ]
    
    // Optional claims
    optionalClaims: {
      accessToken: [
        {
          name: 'groups'
          essential: false
        }
        {
          name: 'preferred_username'
          essential: false
        }
      ]
      idToken: [
        {
          name: 'groups'
          essential: false
        }
      ]
    }
    
    // Application information
    marketingUrl: 'https://contoso.com/products/enterprise-app'
    privacyStatementUrl: 'https://contoso.com/privacy'
    supportUrl: 'https://support.contoso.com/enterprise-app'
    termsOfServiceUrl: 'https://contoso.com/terms'
    
    // Enterprise metadata
    tags: ['enterprise', 'critical', 'security-enhanced', 'line-of-business']
    notes: 'Critical enterprise application requiring enhanced security measures'
    serviceManagementReference: 'ITSM-12345'
  }
}
```

### Multi-Platform Application

```bicep
module multiPlatformApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'myMultiPlatformApp'
  params: {
    displayName: 'Multi-Platform Application'
    uniqueName: 'multi-platform-app-001'
    description: 'Application supporting web, SPA, and mobile platforms'
    signInAudience: 'AzureADMultipleOrgs'
    
    // Web platform
    webRedirectUris: [
      'https://multiapp.azurewebsites.net/signin-oidc'
    ]
    homePageUrl: 'https://multiapp.azurewebsites.net'
    logoutUrl: 'https://multiapp.azurewebsites.net/signout-oidc'
    enableIdTokenIssuance: true
    
    // SPA platform
    spaRedirectUris: [
      'https://multiapp.azurewebsites.net/spa/auth/callback'
    ]
    
    // Mobile platform
    publicClientRedirectUris: [
      'msauth.com.contoso.multiapp://auth'
    ]
    isFallbackPublicClient: true
    
    // Token configuration
    requestedAccessTokenVersion: 2
    
    // Comprehensive permissions
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '37f7f235-527c-4136-accd-4a02d197296e' // User.ReadBasic.All
            type: 'Scope'
          }
        ]
      }
    ]
    
    tags: ['multi-platform', 'web', 'spa', 'mobile']
  }
}
```

## 🔗 Integration Examples

### Use with Service Principal

```bicep
// Create application
module app 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'myApplication'
  params: {
    displayName: 'My Application'
    uniqueName: 'my-application-001'
    signInAudience: 'AzureADMyOrg'
    webRedirectUris: ['https://myapp.contoso.com/signin-oidc']
  }
}

// Create service principal for the application
module servicePrincipal 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'myServicePrincipal'
  params: {
    appId: app.outputs.applicationId
    displayName: app.outputs.displayName
    appRoleAssignmentRequired: true
  }
}
```

### Use with Federated Identity Credentials

```bicep
// Create application
module githubApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'githubActionsApp'
  params: {
    displayName: 'GitHub Actions App'
    uniqueName: 'github-actions-app-001'
    signInAudience: 'AzureADMyOrg'
  }
}

// Add federated identity credential for GitHub Actions
module federatedCredential 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'githubFederatedCredential'
  params: {
    parentApplicationId: githubApp.outputs.objectId
    name: 'github-actions-main'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:myorg/myrepo:ref:refs/heads/main'
    audiences: ['api://AzureADTokenExchange']
    description: 'Federated credential for GitHub Actions main branch'
  }
}
```

## 🔒 Security Best Practices

1. **Least Privilege**: Only request the minimum required permissions
2. **Secure Redirect URIs**: Use HTTPS for all production redirect URIs
3. **Token Validation**: Implement proper token validation in your applications
4. **Regular Reviews**: Periodically review and update API permissions
5. **Certificate Auth**: Prefer certificate-based authentication over client secrets
6. **Audience Restrictions**: Use `AzureADMyOrg` for internal applications
7. **Sign-in Security**: Enable `requireClientServicePrincipal` for enhanced security
8. **Claims Validation**: Remove unverified claims using `removeUnverifiedEmailClaim`

## 🐛 Troubleshooting

### Common Issues

1. **Invalid Redirect URI**: Ensure redirect URIs use HTTPS and match exactly
2. **Permission Scope Errors**: Verify permission IDs are correct UUIDs
3. **Duplicate uniqueName**: Each application must have a unique `uniqueName`
4. **Invalid signInAudience**: Must be one of the four supported values
5. **App Role ID Conflicts**: Ensure app role IDs are unique UUIDs

### Validation Tips

- Use `az deployment group what-if` to validate before deployment
- Check that all GUIDs are properly formatted (36 characters with hyphens)
- Verify redirect URIs don't contain query parameters or fragments
- Ensure app role values don't exceed 120 characters

## 📚 References

- [Microsoft Graph applications resource type](https://learn.microsoft.com/en-us/graph/templates/bicep/reference/applications?view=graph-bicep-1.0)
- [Azure AD Application Registration](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Microsoft Graph permissions reference](https://docs.microsoft.com/en-us/graph/permissions-reference)
- [OAuth 2.0 and OpenID Connect protocols](https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-protocols)
    ]
    homePageUrl: 'https://myapp.azurewebsites.net'
    logoutUrl: 'https://myapp.azurewebsites.net/signout-oidc'
  }
}
```

### Single Page Application (SPA)

```bicep
module spaApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'mySpaApp'
  params: {
    displayName: 'My SPA Application'
    appDescription: 'A React single page application'
    signInAudience: 'AzureADMyOrg'
    spaRedirectUris: [
      'http://localhost:3000'
      'https://myspa.azurewebsites.net'
    ]
    enableIdTokenIssuance: true
  }
}
```

### API with App Roles

```bicep
module apiApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'myApiApp'
  params: {
    displayName: 'My API Application'
    appDescription: 'Backend API with custom roles'
    signInAudience: 'AzureADMyOrg'
    identifierUris: [
      'api://myapi'
    ]
    appRoles: [
      {
        allowedMemberTypes: ['Application']
        description: 'Access to read data'
        displayName: 'Data.Read'
        id: '00000000-0000-0000-0000-000000000001'
        isEnabled: true
        value: 'Data.Read'
      }
      {
        allowedMemberTypes: ['Application']
        description: 'Access to write data'
        displayName: 'Data.Write'
        id: '00000000-0000-0000-0000-000000000002'
        isEnabled: true
        value: 'Data.Write'
      }
    ]
  }
}
```

### Application with API Permissions

```bicep
module clientApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'myClientApp'
  params: {
    displayName: 'My Client Application'
    appDescription: 'Client app that calls Microsoft Graph'
    signInAudience: 'AzureADMyOrg'
    webRedirectUris: [
      'https://myclient.azurewebsites.net/signin-oidc'
    ]
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '06da0dbc-49e2-44d2-8312-53f166ab848a' // Directory.Read.All
            type: 'Role'
          }
        ]
      }
    ]
  }
}
```

## Best Practices

1. **Use descriptive names**: Choose clear, meaningful names for your applications
2. **Minimal permissions**: Only request the permissions your application actually needs
3. **Environment-specific configuration**: Use different redirect URIs for different environments
4. **Secure configuration**: Avoid storing sensitive information in parameters
5. **Documentation**: Always provide descriptions for your applications

## Prerequisites

- Microsoft Graph Bicep provider must be configured
- Appropriate permissions to create applications in Azure AD
- Understanding of OAuth 2.0 and OpenID Connect flows

## Security Considerations

- Review and validate all redirect URIs
- Use HTTPS for all production redirect URIs
- Implement proper token validation in your applications
- Regularly review and update API permissions
- Consider using managed identities where possible

## Troubleshooting

### Common Issues

1. **Permission errors**: Ensure you have Application Administrator or Global Administrator role
2. **Invalid redirect URIs**: Verify URIs are properly formatted and use HTTPS in production
3. **Duplicate identifiers**: Ensure identifier URIs are unique across your tenant

### Debugging

Check the deployment logs for detailed error messages. Common validation errors include:
- Invalid URI formats
- Duplicate application names
- Missing required permissions

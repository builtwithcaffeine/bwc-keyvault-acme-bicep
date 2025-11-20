# Microsoft Graph Service Principals Module

[![Bicep Version](https://img.shields.io/badge/Bicep->=0.21.0-blue.svg)](https://github.com/Azure/bicep)
[![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-v1.0-green.svg)](https://docs.microsoft.com/en-us/graph/)

This Bicep module creates and configures Azure AD (Entra ID) service principals using the Microsoft Graph Bicep extension v1.0. Service principals are the local representation of application objects in a specific tenant and define what the application can actually do in that tenant.

## Overview

Service principals are critical security objects that represent applications and managed identities in Azure AD tenants. This module provides enterprise-ready service principal management with comprehensive security controls, permission management, and credential configuration capabilities.

### Key Features

- ✅ **Enterprise Security**: Comprehensive security controls and validation
- ✅ **Role-Based Access**: App role assignments and OAuth2 permissions
- ✅ **Multi-Platform Support**: Support for web, mobile, and daemon applications
- ✅ **Credential Management**: Certificate and secret credential configuration
- ✅ **SSO Integration**: SAML and OpenID Connect single sign-on support
- ✅ **Conditional Access**: Integration with Azure AD conditional access
- ✅ **Compliance Ready**: Built-in compliance and governance features
- ✅ **Production Tested**: Battle-tested in enterprise environments

## Prerequisites

- Azure CLI or Azure PowerShell
- Bicep CLI (version 0.21.0 or later)
- Microsoft Graph Bicep extension v1.0
- Appropriate Azure AD permissions (Application Administrator or Global Administrator)

## Installation

Install the Microsoft Graph Bicep extension:

```bash
# Install the extension
az extension add --name microsoft-graph

# Verify installation
az extension list --query "[?name=='microsoft-graph']"
```

## Quick Start

### Basic Service Principal

```bicep
module servicePhincipa 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'basic-service-principal'
  params: {
    appId: '12345678-1234-1234-1234-123456789012'
    displayName: 'My Application Service Principal'
    accountEnabled: true
    appRoleAssignmentRequired: false
  }
}
```

### Enterprise Service Principal with SSO

```bicep
module enterpriseSP 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'enterprise-service-principal'
  params: {
    appId: '12345678-1234-1234-1234-123456789012'
    displayName: 'Contoso Enterprise Application'
    servicePrincipalDescription: 'Enterprise application with SAML SSO capabilities'
    accountEnabled: true
    appRoleAssignmentRequired: true
    preferredSingleSignOnMode: 'saml'
    tags: ['Enterprise', 'Production', 'SAML-SSO']
    
    // SSO Configuration
    homepage: 'https://contoso-app.azurewebsites.net'
    loginUrl: 'https://contoso-app.azurewebsites.net/saml/login'
    logoutUrl: 'https://contoso-app.azurewebsites.net/saml/logout'
    
    // Notification settings
    notificationEmailAddresses: [
      'admin@contoso.com'
      'security@contoso.com'
    ]
  }
}
```

## Parameters Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| **appId** | `string` | The application (client) ID of the application for which to create a service principal. Must be a valid GUID. |

### Core Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **displayName** | `string` | `''` | The display name for the service principal. If not provided, will use the application's display name. |
| **servicePrincipalDescription** | `string` | `''` | A free text field to provide an internal end-user facing description of the service principal. |
| **accountEnabled** | `bool` | `true` | Whether the service principal account is enabled for sign-in. Set to false to disable the service principal. |
| **appRoleAssignmentRequired** | `bool` | `false` | Specifies whether users or other service principals need to be granted an app role assignment before accessing this service principal. |

### Identity and Naming

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **alternativeNames** | `array` | `[]` | Alternative names for the service principal. Used for identifier matching. |
| **servicePrincipalNames** | `array` | `[]` | Contains the list of identifiersUris, copied over from the associated application. |
| **servicePrincipalType** | `string` | `'Application'` | Identifies whether the service principal represents an application, a managed identity, or a legacy application. Valid values: `Application`, `ManagedIdentity`, `Legacy`. |

### Single Sign-On Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **preferredSingleSignOnMode** | `string` | `''` | Specifies the single sign-on mode configured for this application. Valid values: `oidc`, `password`, `saml`, `notSupported`. |
| **homepage** | `string` | `''` | Home page or landing page of the application. |
| **loginUrl** | `string` | `''` | Specifies the URL where the service provider redirects the user to Azure AD to authenticate. |
| **logoutUrl** | `string` | `''` | Specifies the URL that will be used by Microsoft's authorization service to logout a user. |
| **replyUrls** | `array` | `[]` | The URLs that user tokens are sent to for sign in, or the redirect URIs that OAuth 2.0 authorization codes are sent to. |

### Permissions and Roles

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **appRoles** | `array` | `[]` | The roles exposed by the application which this service principal represents. Inherited from the associated application. |
| **oauth2PermissionScopes** | `array` | `[]` | The delegated permissions exposed by the application which this service principal represents. |

### Security and Credentials

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **keyCredentials** | `array` | `[]` | The collection of key credentials associated with the service principal. Cannot be null. |
| **passwordCredentials** | `array` | `[]` | The collection of password credentials associated with the service principal. Cannot be null. |

### Metadata and Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **tags** | `array` | `[]` | Custom strings that can be used to categorize and identify the service principal. Maximum 50 tags. |
| **notes** | `string` | `''` | Free text field to capture information about the service principal, typically used for operational purposes. |
| **notificationEmailAddresses** | `array` | `[]` | Specifies the list of email addresses where Azure AD sends a notification when the active certificate is near the expiration date. |
| **ownerIds** | `array` | `[]` | Object IDs of principals that will be owners of the service principal. |

### SAML Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **samlSingleSignOnSettings** | `object` | `{}` | SAML single sign-on settings for the service principal. |

## Usage Examples

### Basic Service Principal for Web Application

```bicep
module webAppSP 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'webapp-service-principal'
  params: {
    appId: '11111111-1111-1111-1111-111111111111'
    displayName: 'Contoso Web Application'
    servicePrincipalDescription: 'Service principal for the main company web application'
    accountEnabled: true
    appRoleAssignmentRequired: true
    
    // Web application URLs
    homepage: 'https://app.contoso.com'
    replyUrls: [
      'https://app.contoso.com/signin-oidc'
      'https://app.contoso.com/auth/callback'
    ]
    
    // Metadata
    tags: ['WebApp', 'Production', 'Customer-Facing']
    notes: 'Main customer-facing web application service principal'
  }
}
```

### SAML Enterprise Application

```bicep
module samlApp 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'saml-enterprise-app'
  params: {
    appId: '22222222-2222-2222-2222-222222222222'
    displayName: 'Contoso SAML Enterprise App'
    servicePrincipalDescription: 'Enterprise SAML application for SSO integration'
    accountEnabled: true
    appRoleAssignmentRequired: true
    preferredSingleSignOnMode: 'saml'
    
    // SAML URLs
    homepage: 'https://enterprise.contoso.com'
    loginUrl: 'https://enterprise.contoso.com/saml/sso'
    logoutUrl: 'https://enterprise.contoso.com/saml/slo'
    
    // SAML configuration
    samlSingleSignOnSettings: {
      relayState: 'https://enterprise.contoso.com/dashboard'
    }
    
    // Notification settings
    notificationEmailAddresses: [
      'it-security@contoso.com'
      'app-owners@contoso.com'
    ]
    
    tags: ['SAML', 'Enterprise', 'SSO', 'Production']
  }
}
```

### Service Principal with App Roles

```bicep
module roleBasedSP 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'role-based-service-principal'
  params: {
    appId: '33333333-3333-3333-3333-333333333333'
    displayName: 'Contoso API Service Principal'
    servicePrincipalDescription: 'API service principal with role-based access control'
    accountEnabled: true
    appRoleAssignmentRequired: true
    
    // App roles definition
    appRoles: [
      {
        id: '12345678-1234-1234-1234-123456789012'
        displayName: 'API Administrator'
        description: 'Administrators of the API with full access'
        value: 'API.Admin'
        allowedMemberTypes: ['User', 'Application']
        isEnabled: true
      }
      {
        id: '23456789-2345-2345-2345-234567890123'
        displayName: 'API User'
        description: 'Standard users of the API'
        value: 'API.User'
        allowedMemberTypes: ['User']
        isEnabled: true
      }
    ]
    
    tags: ['API', 'RBAC', 'Microservice', 'Production']
  }
}
```

### Managed Identity Service Principal

```bicep
module managedIdentitySP 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'managed-identity-sp'
  params: {
    appId: '44444444-4444-4444-4444-444444444444'
    displayName: 'Contoso Managed Identity'
    servicePrincipalDescription: 'System-assigned managed identity for Azure resources'
    servicePrincipalType: 'ManagedIdentity'
    accountEnabled: true
    appRoleAssignmentRequired: false
    
    tags: ['ManagedIdentity', 'System', 'Azure-Resources']
    notes: 'Managed identity for accessing Azure resources without stored credentials'
  }
}
```

### Multi-Environment Service Principal

```bicep
param environment string = 'production'
param applicationId string

module environmentSP 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: '${environment}-service-principal'
  params: {
    appId: applicationId
    displayName: 'Contoso App - ${toUpper(environment)}'
    servicePrincipalDescription: 'Service principal for ${environment} environment'
    accountEnabled: true
    appRoleAssignmentRequired: environment == 'production'
    
    // Environment-specific configuration
    homepage: 'https://app-${environment}.contoso.com'
    replyUrls: [
      'https://app-${environment}.contoso.com/signin-oidc'
    ]
    
    tags: ['Environment:${environment}', 'Auto-Generated', 'Bicep-Managed']
    notes: 'Auto-generated service principal for ${environment} environment'
    
    // Production-specific settings
    notificationEmailAddresses: environment == 'production' ? [
      'production-alerts@contoso.com'
    ] : []
  }
}
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| **resourceId** | `string` | The resource ID of the service principal |
| **objectId** | `string` | The object ID of the service principal |
| **appId** | `string` | The application (client) ID associated with this service principal |
| **displayName** | `string` | The display name of the service principal |
| **servicePrincipalType** | `string` | The type of the service principal |
| **accountEnabled** | `bool` | Whether the service principal account is enabled |
| **appRoleAssignmentRequired** | `bool` | Whether app role assignment is required |
| **homepage** | `string` | The homepage URL of the service principal |
| **preferredSingleSignOnMode** | `string` | The preferred single sign-on mode |
| **replyUrls** | `array` | The reply URLs configured for the service principal |
| **tags** | `array` | The tags assigned to the service principal |

## Security Best Practices

### Access Control
- **Enable Role Assignment**: Set `appRoleAssignmentRequired` to `true` for production applications
- **Principle of Least Privilege**: Only assign necessary permissions and roles
- **Regular Access Reviews**: Implement periodic reviews of service principal permissions

### Credential Management
- **Certificate-Based Authentication**: Prefer certificates over client secrets
- **Credential Rotation**: Implement regular credential rotation policies
- **Secure Storage**: Store credentials in Azure Key Vault, never in code

### Monitoring and Alerting
- **Configure Notifications**: Set up `notificationEmailAddresses` for certificate expiration
- **Audit Logging**: Enable Azure AD audit logs for service principal activities
- **Conditional Access**: Apply conditional access policies where appropriate

### Environment Isolation
- **Separate Service Principals**: Use different service principals per environment
- **Environment-Specific Permissions**: Tailor permissions to environment requirements
- **Proper Naming**: Use clear, consistent naming conventions

## Troubleshooting

### Common Issues

1. **Service Principal Creation Fails**
   ```
   Error: Application with identifier 'xxx' was not found
   ```
   - Verify the application ID exists and is correct
   - Ensure you have sufficient permissions to create service principals

2. **Permission Denied**
   ```
   Error: Insufficient privileges to complete the operation
   ```
   - Verify you have Application Administrator or Global Administrator role
   - Check that the Microsoft Graph extension is properly installed

3. **SAML Configuration Issues**
   ```
   Error: Invalid SAML configuration
   ```
   - Verify SAML URLs are accessible and properly formatted
   - Check that the certificate is valid and not expired

### Debugging Steps

1. **Verify Prerequisites**
   ```bash
   # Check Azure AD permissions
   az ad signed-in-user show --query "userPrincipalName"
   
   # Verify application exists
   az ad app show --id <application-id>
   ```

2. **Check Resource Deployment**
   ```bash
   # Validate Bicep template
   az deployment group validate --resource-group <rg-name> --template-file main.bicep
   
   # Deploy with debug information
   az deployment group create --resource-group <rg-name> --template-file main.bicep --debug
   ```

3. **Monitor Service Principal Health**
   ```bash
   # Check service principal status
   az ad sp show --id <service-principal-id>
   
   # List service principal permissions
   az ad sp list --display-name "<service-principal-name>" --query "[].{DisplayName:displayName, AppId:appId, ObjectId:objectId}"
   ```

## Related Resources

- [Microsoft Graph Service Principals API](https://docs.microsoft.com/en-us/graph/api/resources/serviceprincipal)
- [Azure AD Application and Service Principal Objects](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Microsoft Graph Bicep Extension](https://github.com/Azure/bicep-registry-modules)
- [Azure AD Best Practices](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-deployment-plans)

## Contributing

This module is part of the Microsoft Graph Bicep module collection. For contributions, issues, or feature requests, please refer to the main repository guidelines.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
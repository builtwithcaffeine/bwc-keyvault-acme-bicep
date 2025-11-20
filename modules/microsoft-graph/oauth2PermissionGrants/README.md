# Microsoft Graph OAuth2 Permission Grants Module

[![Bicep Version](https://img.shields.io/badge/Bicep->=0.21.0-blue.svg)](https://github.com/Azure/bicep)
[![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-v1.0-green.svg)](https://docs.microsoft.com/en-us/graph/)

This Bicep module creates and manages OAuth2 permission grants for service principals using the Microsoft Graph Bicep extension v1.0. OAuth2 permission grants represent the authorization given to a client application to access a specific resource on behalf of users, enabling automated consent management for applications that need to access Microsoft Graph APIs or other protected resources.

## Overview

OAuth2 permission grants are fundamental to modern application authorization in Azure AD (Entra ID). They represent the consent given to an application to access resources on behalf of users. This module simplifies the process of creating these grants through Infrastructure as Code, ensuring consistent and auditable consent management across your organization.

### Key Features

- ✅ **Delegated Permissions**: Grant applications permission to act on behalf of users
- ✅ **Administrative Consent**: Support for organization-wide consent (AllPrincipals)
- ✅ **User-Specific Consent**: Granular consent for individual users (Principal)
- ✅ **Scope Management**: Precise control over delegated permission scopes
- ✅ **Microsoft Graph Integration**: Direct integration with Microsoft Graph API
- ✅ **Automated Consent**: Eliminate manual consent prompts for trusted applications
- ✅ **Audit Trail**: Full deployment history and compliance tracking
- ✅ **Multi-Resource Support**: Grant access to multiple resource APIs

## Prerequisites

- Azure CLI or Azure PowerShell
- Bicep CLI (version 0.21.0 or later)
- Microsoft Graph Bicep extension v1.0
- Appropriate Azure AD permissions (Application Administrator, Cloud Application Administrator, or Global Administrator)
- Existing service principals for both client and resource applications

## Installation

Install the Microsoft Graph Bicep extension:

```bash
# Install the extension
az extension add --name microsoft-graph

# Verify installation
az extension list --query "[?name=='microsoft-graph']"
```

## Quick Start

### Organization-Wide Consent (AllPrincipals)

```bicep
module organizationConsent 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'organization-wide-consent'
  params: {
    clientId: '11111111-1111-1111-1111-111111111111'
    consentType: 'AllPrincipals'
    resourceId: '22222222-2222-2222-2222-222222222222'
    scope: 'User.Read Directory.Read.All'
  }
}
```

### User-Specific Consent (Principal)

```bicep
module userSpecificConsent 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'user-specific-consent'
  params: {
    clientId: '11111111-1111-1111-1111-111111111111'
    consentType: 'Principal'
    principalId: '33333333-3333-3333-3333-333333333333'
    resourceId: '22222222-2222-2222-2222-222222222222'
    scope: 'User.Read Calendars.Read'
  }
}
```

## Parameters Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| **clientId** | `string` | The unique identifier for the client service principal (the application requesting access). |
| **consentType** | `string` | Type of consent. Valid values: `AllPrincipals` (organization-wide), `Principal` (user-specific). |
| **resourceId** | `string` | The unique identifier for the resource service principal (the API being accessed). |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **principalId** | `string` | `''` | The user object ID when `consentType` is `Principal`. Required for user-specific consent, ignored for organization-wide consent. |
| **scope** | `string` | `''` | Space-separated list of delegated permission scopes to grant (e.g., `'User.Read Calendars.Read'`). |

## Usage Examples

### Microsoft Graph API Access

```bicep
// Grant organization-wide access to Microsoft Graph
module graphOrganizationAccess 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'graph-organization-access'
  params: {
    clientId: '11111111-1111-1111-1111-111111111111'        // Your app's service principal
    consentType: 'AllPrincipals'
    resourceId: '00000003-0000-0000-c000-000000000000'      // Microsoft Graph service principal
    scope: 'User.Read Directory.Read.All Group.Read.All'
  }
}
```

### Custom API Access

```bicep
// Grant access to your custom API
module customApiAccess 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'custom-api-access'
  params: {
    clientId: '22222222-2222-2222-2222-222222222222'        // Client app service principal
    consentType: 'AllPrincipals'
    resourceId: '33333333-3333-3333-3333-333333333333'      // Your API service principal
    scope: 'api://customer-api/Customer.Read api://customer-api/Customer.Write'
  }
}
```

### User-Specific Permissions

```bicep
// Grant permissions for a specific user only
module userOnlyAccess 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'user-only-access'
  params: {
    clientId: '44444444-4444-4444-4444-444444444444'
    consentType: 'Principal'
    principalId: '55555555-5555-5555-5555-555555555555'     // Specific user object ID
    resourceId: '00000003-0000-0000-c000-000000000000'      // Microsoft Graph
    scope: 'User.Read Calendars.Read.Shared'
  }
}
```

### Office 365 SharePoint Access

```bicep
// Grant SharePoint Online permissions
module sharepointAccess 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'sharepoint-access'
  params: {
    clientId: '66666666-6666-6666-6666-666666666666'
    consentType: 'AllPrincipals'
    resourceId: '00000003-0000-0ff1-ce00-000000000000'      // SharePoint Online service principal
    scope: 'Sites.Read.All Files.Read.All'
  }
}
```

### Exchange Online Access

```bicep
// Grant Exchange Online permissions
module exchangeAccess 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'exchange-access'
  params: {
    clientId: '77777777-7777-7777-7777-777777777777'
    consentType: 'AllPrincipals'
    resourceId: '00000002-0000-0ff1-ce00-000000000000'      // Exchange Online service principal
    scope: 'Mail.Read Calendars.Read'
  }
}
```

### Multi-Scope Graph Permissions

```bicep
// Comprehensive Microsoft Graph permissions for an enterprise application
module enterpriseGraphAccess 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'enterprise-graph-access'
  params: {
    clientId: '88888888-8888-8888-8888-888888888888'
    consentType: 'AllPrincipals'
    resourceId: '00000003-0000-0000-c000-000000000000'
    scope: join([
      'User.Read'
      'User.ReadBasic.All'
      'Group.Read.All'
      'Directory.Read.All'
      'Calendars.Read'
      'Mail.Read'
      'Files.Read.All'
      'Sites.Read.All'
    ], ' ')
  }
}
```

### Conditional Access Based on Environment

```bicep
param environment string = 'production'
param clientServicePrincipalId string = '99999999-9999-9999-9999-999999999999'

// Different scopes based on environment
module environmentSpecificAccess 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'environment-specific-access'
  params: {
    clientId: clientServicePrincipalId
    consentType: 'AllPrincipals'
    resourceId: '00000003-0000-0000-c000-000000000000'
    scope: environment == 'production' ? 'User.Read Directory.Read.All' : 'User.Read Group.Read.All Directory.Read.All'
  }
}
```

### Batch Permission Grants

```bicep
// Define multiple permission grants for different resources
param permissionGrants array = [
  {
    name: 'graph-permissions'
    clientId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    resourceId: '00000003-0000-0000-c000-000000000000'  // Microsoft Graph
    scope: 'User.Read Directory.Read.All'
  }
  {
    name: 'sharepoint-permissions'
    clientId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    resourceId: '00000003-0000-0ff1-ce00-000000000000'  // SharePoint
    scope: 'Sites.Read.All Files.Read.All'
  }
  {
    name: 'exchange-permissions'
    clientId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    resourceId: '00000002-0000-0ff1-ce00-000000000000'  // Exchange
    scope: 'Mail.Read Calendars.Read'
  }
]

// Create multiple permission grants
module batchPermissionGrants 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = [for (grant, index) in permissionGrants: {
  name: 'batch-grant-${grant.name}-${index}'
  params: {
    clientId: grant.clientId
    consentType: 'AllPrincipals'
    resourceId: grant.resourceId
    scope: grant.scope
  }
}]
```

### DevOps Pipeline Application

```bicep
// Grant permissions for a DevOps/CI-CD application
module devopsAppPermissions 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  name: 'devops-app-permissions'
  params: {
    clientId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'        // DevOps app service principal
    consentType: 'AllPrincipals'
    resourceId: '00000003-0000-0000-c000-000000000000'      // Microsoft Graph
    scope: join([
      'Application.ReadWrite.All'
      'Directory.ReadWrite.All'
      'Group.ReadWrite.All'
      'User.ReadWrite.All'
    ], ' ')
  }
}
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| **resourceId** | `string` | The unique resource ID of the OAuth2 permission grant |
| **oauth2PermissionGrantId** | `string` | The OAuth2 permission grant identifier |
| **clientId** | `string` | The client service principal ID that received the grant |
| **consentType** | `string` | The type of consent granted (AllPrincipals or Principal) |
| **principalId** | `string` | The specific user ID (if Principal consent type) |
| **resourceServicePrincipalId** | `string` | The resource service principal ID that permissions were granted for |
| **scope** | `string` | The delegated permission scopes that were granted |

## Common Permission Scopes

### Microsoft Graph (00000003-0000-0000-c000-000000000000)

#### User Permissions
- `User.Read` - Read user profile
- `User.ReadBasic.All` - Read all users' basic profiles
- `User.ReadWrite` - Read and write user profile
- `User.ReadWrite.All` - Read and write all users' profiles

#### Directory Permissions
- `Directory.Read.All` - Read directory data
- `Directory.ReadWrite.All` - Read and write directory data
- `Directory.AccessAsUser.All` - Access directory as signed-in user

#### Group Permissions
- `Group.Read.All` - Read all groups
- `Group.ReadWrite.All` - Read and write all groups

#### Application Permissions
- `Application.Read.All` - Read applications
- `Application.ReadWrite.All` - Read and write applications

#### Calendar Permissions
- `Calendars.Read` - Read user calendars
- `Calendars.ReadWrite` - Read and write user calendars
- `Calendars.Read.Shared` - Read shared calendars

#### Mail Permissions
- `Mail.Read` - Read user mail
- `Mail.ReadWrite` - Read and write user mail
- `Mail.Send` - Send mail as user

#### Files Permissions
- `Files.Read` - Read user files
- `Files.ReadWrite` - Read and write user files
- `Files.Read.All` - Read all files
- `Files.ReadWrite.All` - Read and write all files

### SharePoint Online (00000003-0000-0ff1-ce00-000000000000)

- `Sites.Read.All` - Read items in all site collections
- `Sites.ReadWrite.All` - Read and write items in all site collections
- `Sites.Manage.All` - Manage all site collections
- `Sites.FullControl.All` - Full control of all site collections

### Exchange Online (00000002-0000-0ff1-ce00-000000000000)

- `Mail.Read` - Read user mail
- `Mail.ReadWrite` - Read and write user mail
- `Mail.Send` - Send mail as user
- `Calendars.Read` - Read user calendars
- `Calendars.ReadWrite` - Read and write user calendars

## Consent Types

### AllPrincipals
- **Description**: Grants permission for all users in the organization
- **Use Case**: Enterprise applications that need consistent access across all users
- **Security Consideration**: Affects all users, requires careful scope selection
- **Required Parameters**: `clientId`, `resourceId`, `scope`

### Principal
- **Description**: Grants permission for a specific user only
- **Use Case**: User-specific applications or limited access scenarios
- **Security Consideration**: More granular control, affects only specified user
- **Required Parameters**: `clientId`, `resourceId`, `principalId`, `scope`

## Security Best Practices

### Scope Management
- **Least Privilege**: Only grant the minimum required scopes
- **Regular Audits**: Periodically review and clean up unnecessary grants
- **Scope Documentation**: Maintain clear documentation of why each scope is needed
- **Environment Separation**: Use different scopes for different environments

### Consent Management
- **Administrative Oversight**: Require approval for AllPrincipals consent
- **User Education**: Educate users about the implications of consent
- **Monitoring**: Implement monitoring for new permission grants
- **Revocation Process**: Have a clear process for revoking permissions

### Application Security
- **Service Principal Management**: Secure service principal credentials
- **Certificate Authentication**: Use certificates instead of client secrets where possible
- **Credential Rotation**: Implement regular credential rotation
- **Access Reviews**: Conduct regular access reviews

## Troubleshooting

### Common Issues

1. **Grant Already Exists**
   ```
   Error: OAuth2 permission grant already exists
   ```
   - Check existing grants using Azure portal or PowerShell
   - Remove duplicate grants before creating new ones

2. **Invalid Client ID**
   ```
   Error: Client service principal not found
   ```
   - Verify the client service principal exists in Azure AD
   - Check the service principal object ID

3. **Invalid Resource ID**
   ```
   Error: Resource service principal not found
   ```
   - Verify the resource service principal exists
   - For Microsoft Graph, use: `00000003-0000-0000-c000-000000000000`

4. **Invalid Scope**
   ```
   Error: Invalid scope for resource
   ```
   - Check the resource's published permission scopes
   - Verify scope names match exactly (case-sensitive)

5. **Insufficient Permissions**
   ```
   Error: Insufficient privileges to complete the operation
   ```
   - Ensure you have Application Administrator or higher privileges
   - Check tenant policies for permission grant restrictions

### Debugging Steps

1. **Verify Prerequisites**
   ```bash
   # Check if client service principal exists
   az ad sp show --id <client-id>
   
   # Check if resource service principal exists
   az ad sp show --id <resource-id>
   
   # List current permission grants for client
   az ad sp show --id <client-id> --query "oauth2PermissionGrants"
   ```

2. **Validate Scopes**
   ```bash
   # List available scopes for Microsoft Graph
   az ad sp show --id 00000003-0000-0000-c000-000000000000 --query "oauth2Permissions"
   
   # List available scopes for a custom API
   az ad sp show --id <resource-id> --query "oauth2Permissions"
   ```

3. **Check Existing Grants**
   ```bash
   # List all OAuth2 permission grants
   az rest --method GET --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants"
   
   # Filter by client ID
   az rest --method GET --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq '<client-id>'"
   ```

## Related Resources

- [Microsoft Graph OAuth2 Permission Grants API](https://docs.microsoft.com/en-us/graph/api/resources/oauth2permissiongrant)
- [Microsoft Graph Permissions Reference](https://docs.microsoft.com/en-us/graph/permissions-reference)
- [Azure AD Application Consent Experience](https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/application-consent-experience)
- [Delegated and Application Permissions](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-permissions-and-consent)
- [Admin Consent for Applications](https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/grant-admin-consent)

## Contributing

This module is part of the Microsoft Graph Bicep module collection. For contributions, issues, or feature requests, please refer to the main repository guidelines.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
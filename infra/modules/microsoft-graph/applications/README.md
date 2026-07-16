# Microsoft Graph Application Module

Creates Microsoft Entra application registrations through the Microsoft Graph Bicep extension.

## Parameters

### Required

| Name | Type | Description |
| --- | --- | --- |
| `displayName` | `string` | Application display name. |
| `appName` | `string` | Unique name used as `uniqueName` in Graph resource. |

### Optional (high-usage)

| Name | Type | Default |
| --- | --- | --- |
| `appDescription` | `string` | `''` |
| `signInAudience` | `string` | `'AzureADMyOrg'` |
| `webRedirectUris` | `array` | `[]` |
| `spaRedirectUris` | `array` | `[]` |
| `publicClientRedirectUris` | `array` | `[]` |
| `homePageUrl` | `string` | `''` |
| `logoutUrl` | `string` | `''` |
| `identifierUris` | `array` | `[]` |
| `requiredResourceAccess` | `array` | `[]` |
| `appRoles` | `array` | `[]` |
| `oauth2PermissionScopes` | `array` | `[]` |
| `ownerIds` | `array` | `[]` |
| `tags` | `array` | `[]` |
| `notes` | `string` | `''` |

See `main.bicep` for full advanced parameters (token settings, optional claims, SAML/native auth, etc.).

## Outputs

- `resourceId`
- `applicationId`
- `objectId`
- `displayName`
- `uniqueName`
- `signInAudience`
- `isFallbackPublicClient`
- `isDeviceOnlyAuthSupported`
- `identifierUris`
- `defaultRedirectUri`
- `groupMembershipClaims`
- `tags`
- `description`
- `webConfiguration`
- `spaConfiguration`
- `publicClientConfiguration`
- `apiConfiguration`
- `applicationCredentials`
- `credentialCount`

## Examples

### Basic web application

```bicep
module webApp 'modules/microsoft-graph/applications/main.bicep' = {
  params: {
    displayName: 'Contoso Web App'
    appName: 'contoso-web-app'
    appDescription: 'Customer-facing web application'
    signInAudience: 'AzureADMyOrg'
    webRedirectUris: [
      'https://app.contoso.com/signin-oidc'
      'https://localhost:5001/signin-oidc'
    ]
    homePageUrl: 'https://app.contoso.com'
    logoutUrl: 'https://app.contoso.com/signout-oidc'
    enableIdTokenIssuance: true
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000'
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
            type: 'Scope'
          }
        ]
      }
    ]
  }
}
```

### Single-page application (SPA)

```bicep
module spaApp 'modules/microsoft-graph/applications/main.bicep' = {
  params: {
    displayName: 'Contoso SPA'
    appName: 'contoso-spa'
    appDescription: 'Single page front-end'
    spaRedirectUris: [
      'https://spa.contoso.com/auth/callback'
      'http://localhost:3000/auth/callback'
    ]
    signInAudience: 'AzureADMyOrg'
    requestedAccessTokenVersion: 2
  }
}
```

### API with app roles

```bicep
module apiApp 'modules/microsoft-graph/applications/main.bicep' = {
  params: {
    displayName: 'Contoso API'
    appName: 'contoso-api'
    appDescription: 'Backend API'
    identifierUris: [
      'api://contoso-api'
    ]
    appRoles: [
      {
        id: '00000000-0000-0000-0000-000000000001'
        displayName: 'Api.Reader'
        description: 'Read access to API'
        value: 'Api.Reader'
        allowedMemberTypes: [
          'Application'
          'User'
        ]
        isEnabled: true
      }
    ]
    oauth2PermissionScopes: [
      {
        id: '00000000-0000-0000-0000-000000000002'
        adminConsentDisplayName: 'Read API data'
        adminConsentDescription: 'Allow reading API data'
        userConsentDisplayName: 'Read API data'
        userConsentDescription: 'Allow reading API data'
        value: 'api.read'
        type: 'User'
        isEnabled: true
      }
    ]
  }
}
```

## Notes

- This module uses extension alias `microsoftGraphV1` from `bicepconfig.json`.
- `appName` maps to Graph `uniqueName`.
- Use `ownerIds` with Entra object IDs when assigning owners.

---

*Last updated: 2026-07-16*

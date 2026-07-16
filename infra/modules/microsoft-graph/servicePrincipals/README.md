# Microsoft Graph Service Principals Module

Creates Microsoft Entra service principals using the Microsoft Graph Bicep extension.

## Parameters

### Required

| Name | Type | Description |
| --- | --- | --- |
| `appId` | `string` | Application (client) ID for which to create/configure the service principal. |

### Optional (high-usage)

| Name | Type | Default |
| --- | --- | --- |
| `displayName` | `string` | `''` |
| `accountEnabled` | `bool` | `true` |
| `appRoleAssignmentRequired` | `bool` | `false` |
| `servicePrincipalType` | `string` | `'Application'` |
| `loginUrl` | `string` | `''` |
| `logoutUrl` | `string` | `''` |
| `replyUrls` | `array` | `[]` |
| `preferredSingleSignOnMode` | `string` | `''` |
| `notificationEmailAddresses` | `array` | `[]` |
| `ownerIds` | `array` | `[]` |
| `tags` | `array` | `[]` |
| `notes` | `string` | `''` |

## Outputs

- `resourceId`
- `servicePrincipalId`
- `appId`
- `displayName`
- `accountEnabled`
- `servicePrincipalType`
- `appRoleAssignmentRequired`
- `servicePrincipalNames`
- `preferredSingleSignOnMode`

## Examples

### Basic service principal

```bicep
module basicSp 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  params: {
    appId: '12345678-1234-1234-1234-123456789012'
    displayName: 'Contoso App SP'
    accountEnabled: true
    appRoleAssignmentRequired: false
    tags: [
      'managed-by-bicep'
      'dev'
    ]
  }
}
```

### Service principal with sso configuration

```bicep
module ssoSp 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  params: {
    appId: '12345678-1234-1234-1234-123456789012'
    displayName: 'Contoso SSO App'
    preferredSingleSignOnMode: 'saml'
    homepage: 'https://app.contoso.com'
    loginUrl: 'https://app.contoso.com/saml/login'
    logoutUrl: 'https://app.contoso.com/saml/logout'
    replyUrls: [
      'https://app.contoso.com/saml/acs'
    ]
    notificationEmailAddresses: [
      'identity-admins@contoso.com'
    ]
    accountEnabled: true
  }
}
```

### Service principal with role assignment required

```bicep
module restrictedSp 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  params: {
    appId: '12345678-1234-1234-1234-123456789012'
    displayName: 'Restricted Contoso API SP'
    appRoleAssignmentRequired: true
    accountEnabled: true
    notes: 'Requires explicit app role assignment before access.'
    ownerIds: [
      '11111111-1111-1111-1111-111111111111'
    ]
    tags: [
      'prod'
      'restricted'
    ]
  }
}
```

## Notes

- Use `ownerIds` as Entra object IDs.
- The older `servicePrincipalDescription` property is not part of this module contract.

---

*Last updated: 2026-07-16*

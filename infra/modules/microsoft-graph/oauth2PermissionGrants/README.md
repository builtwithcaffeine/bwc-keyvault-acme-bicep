# Microsoft Graph OAuth2 Permission Grants Module

Creates delegated OAuth2 permission grants for service principals with the Microsoft Graph Bicep extension.

## Parameters

### Required

| Name | Type | Description |
| --- | --- | --- |
| `clientId` | `string` | Client service principal object ID (the requesting app). |
| `consentType` | `string` | `AllPrincipals` or `Principal`. |
| `resourceId` | `string` | Resource service principal object ID (the target API). |

### Optional

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `principalId` | `string` | `''` | Required when `consentType = 'Principal'`. |
| `scope` | `string` | `''` | Space-separated delegated scopes. |

## Outputs

- `resourceId`
- `oauth2PermissionGrantId`
- `clientId`
- `consentType`
- `principalId`
- `resourceServicePrincipalId`
- `scope`

## Examples

### Organization-wide consent (all principals)

```bicep
module orgGrant 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  params: {
    clientId: '11111111-1111-1111-1111-111111111111'
    consentType: 'AllPrincipals'
    resourceId: '22222222-2222-2222-2222-222222222222'
    scope: 'User.Read Directory.Read.All'
  }
}
```

### User-specific consent (principal)

```bicep
module userGrant 'modules/microsoft-graph/oauth2PermissionGrants/main.bicep' = {
  params: {
    clientId: '11111111-1111-1111-1111-111111111111'
    consentType: 'Principal'
    principalId: '33333333-3333-3333-3333-333333333333'
    resourceId: '22222222-2222-2222-2222-222222222222'
    scope: 'User.Read Mail.Read'
  }
}
```

### Common Microsoft API app IDs

These are **application IDs**. Convert each to its tenant service principal object ID, then pass that value as `resourceId`.

| Service | App ID |
| --- | --- |
| Microsoft Graph | `00000003-0000-0000-c000-000000000000` |
| Azure AD Graph (legacy) | `00000002-0000-0000-c000-000000000000` |
| SharePoint Online | `00000003-0000-0ff1-ce00-000000000000` |
| Exchange Online | `00000002-0000-0ff1-ce00-000000000000` |

## Notes

- `resourceId` must be the **service principal object ID**, not the app ID.
- When `consentType` is `AllPrincipals`, `principalId` is ignored.

---

*Last updated: 2026-07-16*

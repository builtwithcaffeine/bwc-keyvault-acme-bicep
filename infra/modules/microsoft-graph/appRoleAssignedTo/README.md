# Microsoft Graph app role assignment module

Creates app role assignments in Microsoft Entra ID through the Microsoft Graph Bicep extension.

## What this module does

Assigns one app role to one principal.

- Principal can be a user, group, or service principal.
- Resource is the service principal that defines the app role.

## Prerequisites

- Bicep CLI installed (`az bicep version`)
- `microsoftGraphV1` extension alias configured in `bicepconfig.json`
- Microsoft Entra role with permission to create app role assignments

## Parameters

### Required

- `appRoleId` (`string`): app role GUID to assign
- `principalId` (`string`): object ID of recipient principal
- `resourceId` (`string`): object ID of resource/service principal exposing the role
- `resourceDisplayName` (`string`): display name of the target resource service principal

### Optional

- `principalType` (`string`, default `ServicePrincipal`): `User`, `Group`, or `ServicePrincipal`

## Outputs

- `resourceId`
- `appRoleId`
- `principalId`
- `assignedResourceId`
- `principalType`

## Example

```bicep
module roleAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'assign-api-reader-role'
  params: {
    appRoleId: '00000000-0000-0000-0000-000000000001'
    principalId: '11111111-1111-1111-1111-111111111111'
    resourceId: '22222222-2222-2222-2222-222222222222'
    resourceDisplayName: 'Contoso API'
    principalType: 'Group'
  }
}
```

## Troubleshooting

- `Insufficient privileges`: grant appropriate Entra admin role to deployment identity.
- `App role not found`: verify `appRoleId` exists on the target resource application.
- `Principal not found`: verify `principalId` is from the same tenant and object type.

## Related docs

- `QUICKSTART.md`
- `../servicePrincipals/README.md`
- `../oauth2PermissionGrants/README.md`

---

*Last updated: 2026-07-16*

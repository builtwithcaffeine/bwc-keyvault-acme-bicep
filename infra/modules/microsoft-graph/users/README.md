# Microsoft Graph Users Module

References existing Microsoft Entra users via UPN using the Microsoft Graph Bicep extension.

## Parameters

### Required

| Name | Type | Description |
| --- | --- | --- |
| `userPrincipalName` | `string` | Existing user UPN (for example `user@contoso.com`). |

## Outputs

- `resourceId`
- `userId`
- `userPrincipalName`
- `displayName`
- `mail`
- `givenName`
- `surname`
- `jobTitle`
- `mobilePhone`
- `officeLocation`
- `preferredLanguage`
- `businessPhones`

## Examples

### Basic user reference

```bicep
module userRef 'modules/microsoft-graph/users/main.bicep' = {
  params: {
    userPrincipalName: 'john.doe@contoso.com'
  }
}

output referencedUserId string = userRef.outputs.userId
```

### Multiple user references

```bicep
param teamMembers array = [
  'alice.manager@contoso.com'
  'bob.developer@contoso.com'
  'carol.tester@contoso.com'
]

module teamUsers 'modules/microsoft-graph/users/main.bicep' = [for (member, i) in teamMembers: {
  name: 'team-user-${i}'
  params: {
    userPrincipalName: member
  }
}]

output teamMemberIds array = [for i in range(0, length(teamMembers)): teamUsers[i].outputs.userId]
```

### User as application owner

```bicep
module appOwner 'modules/microsoft-graph/users/main.bicep' = {
  params: {
    userPrincipalName: 'owner@contoso.com'
  }
}

module app 'modules/microsoft-graph/applications/main.bicep' = {
  params: {
    displayName: 'Owned App'
    appName: 'owned-app'
    ownerIds: [
      appOwner.outputs.userId
    ]
  }
}
```

## Notes

- This module is an `existing` reference and does not create users.
- Use `userId` output when wiring into group membership (`memberIds`) or ownership fields (`ownerIds`).

---

*Last updated: 2026-07-16*

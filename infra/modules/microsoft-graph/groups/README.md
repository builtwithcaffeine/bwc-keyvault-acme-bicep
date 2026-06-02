# Microsoft Graph Groups Module

This module creates Microsoft Entra ID (Azure AD) groups using the Microsoft Graph Bicep extension.

## What this module supports

- Security groups
- Microsoft 365 (Unified) groups
- Dynamic membership rules
- Optional owner/member assignment
- Optional role-assignable groups

## Prerequisites

- Bicep CLI and Microsoft Graph Bicep extension configured in `bicepconfig.json`
- Permissions to create/manage groups in Microsoft Entra ID

## Required parameters

| Name | Type | Description |
| --- | --- | --- |
| `displayName` | `string` | Group display name |
| `groupName` | `string` | Unique name used by the Graph extension resource |
| `mailNickname` | `string` | Mail alias for the group |

## Optional parameters

| Name | Type | Default | Description |
| --- | --- | ---: | --- |
| `groupDescription` | `string` | `''` | Group description |
| `mailEnabled` | `bool` | `false` | Whether the group is mail-enabled |
| `securityEnabled` | `bool` | `true` | Whether the group is security-enabled |
| `groupTypes` | `array` | `[]` | Include `Unified` for Microsoft 365 groups |
| `isAssignableToRole` | `bool` | `false` | Role-assignable group flag |
| `visibility` | `string` | `'Private'` | `Private`, `Public`, `HiddenMembership` (used for Unified groups) |
| `classification` | `string` | `''` | Group classification |
| `preferredLanguage` | `string` | `''` | Preferred language |
| `preferredDataLocation` | `string` | `''` | Preferred data location |
| `theme` | `string` | `''` | Group theme |
| `membershipRule` | `string` | `''` | Dynamic membership rule |
| `membershipRuleProcessingState` | `string` | `'On'` | `On` or `Paused` |
| `ownerIds` | `array` | `[]` | Owner object IDs |
| `memberIds` | `array` | `[]` | Member object IDs |

## Outputs

| Name | Type | Description |
| --- | --- | --- |
| `resourceId` | `string` | Resource ID of the created group |
| `groupId` | `string` | Group object ID |
| `displayName` | `string` | Group display name |
| `mailNickname` | `string` | Group mail nickname |
| `mailEnabled` | `bool` | Mail-enabled flag |
| `securityEnabled` | `bool` | Security-enabled flag |
| `groupTypes` | `array` | Group types |
| `isAssignableToRole` | `bool` | Role-assignable flag |
| `visibility` | `string` | Group visibility |

## Examples

### Basic security group

```bicep
module group 'modules/microsoft-graph/groups/main.bicep' = {
  params: {
    displayName: 'IT Security Team'
    groupName: 'it-security-team'
    mailNickname: 'itsecurityteam'
    groupDescription: 'Security group for IT team members'
    securityEnabled: true
    mailEnabled: false
  }
}
```

### Microsoft 365 group

```bicep
module group 'modules/microsoft-graph/groups/main.bicep' = {
  params: {
    displayName: 'Marketing Collaboration'
    groupName: 'marketing-collaboration'
    mailNickname: 'marketingcollab'
    groupDescription: 'Unified collaboration group for marketing'
    mailEnabled: true
    securityEnabled: true
    groupTypes: [
      'Unified'
    ]
    visibility: 'Private'
    preferredLanguage: 'en-US'
    preferredDataLocation: 'EUR'
    theme: 'Blue'
  }
}
```

### Role-assignable group

```bicep
module group 'modules/microsoft-graph/groups/main.bicep' = {
  params: {
    displayName: 'Privileged Identity Group'
    groupName: 'privileged-identity-group'
    mailNickname: 'prividentitygroup'
    groupDescription: 'Role-assignable group for privileged operations'
    securityEnabled: true
    mailEnabled: false
    isAssignableToRole: true
  }
}
```

### Dynamic security group

```bicep
module group 'modules/microsoft-graph/groups/main.bicep' = {
  params: {
    displayName: 'Enabled Users Dynamic Group'
    groupName: 'enabled-users-dynamic'
    mailNickname: 'enabledusersdynamic'
    securityEnabled: true
    mailEnabled: false
    membershipRule: '(user.accountEnabled -eq true)'
    membershipRuleProcessingState: 'On'
  }
}
```

## Testing

See `test/main.test.bicep` for multi-scenario examples used to validate this module.

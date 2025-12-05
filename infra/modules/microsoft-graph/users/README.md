# Microsoft Graph Users Module

[![Bicep Version](https://img.shields.io/badge/Bicep->=0.21.0-blue.svg)](https://github.com/Azure/bicep)
[![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-v1.0-green.svg)](https://docs.microsoft.com/en-us/graph/)

This Bicep module provides a standardized way to reference existing Azure AD (Entra ID) users using the Microsoft Graph Bicep extension v1.0. It serves as a bridge for incorporating user information into Infrastructure as Code deployments, enabling consistent user references across different modules and resources.

## Overview

The users module simplifies the process of referencing existing Azure AD users in Bicep templates. Instead of hard-coding user object IDs or managing complex user lookups, this module provides a clean interface for referencing users by their User Principal Name (UPN) and outputs comprehensive user information for use in other resources.

### Key Features

- ✅ **User Reference**: Simple interface to reference existing users by UPN
- ✅ **Comprehensive Outputs**: Full user profile information available for downstream use
- ✅ **Integration Ready**: Designed for seamless integration with other Microsoft Graph modules
- ✅ **Enterprise Patterns**: Support for bulk user operations and team assignments
- ✅ **Type Safety**: Strong typing ensures reliable user property access
- ✅ **Error Handling**: Clear error messages for common user reference issues
- ✅ **Security Compliance**: Follows Azure AD security best practices
- ✅ **Audit Trail**: Full deployment history and user assignment tracking

## Prerequisites

- Azure CLI or Azure PowerShell
- Bicep CLI (version 0.21.0 or later)
- Microsoft Graph Bicep extension v1.0
- Appropriate Azure AD permissions (User.Read.All or Directory.Read.All)
- Existing users in Azure AD with valid User Principal Names

## Installation

Install the Microsoft Graph Bicep extension:

```bash
# Install the extension
az extension add --name microsoft-graph

# Verify installation
az extension list --query "[?name=='microsoft-graph']"
```

## Quick Start

### Basic User Reference

```bicep
module salesUser 'modules/microsoft-graph/users/main.bicep' = {
  name: 'sales-user-reference'
  params: {
    userPrincipalName: 'john.doe@contoso.com'
  }
}

// Use the user information in another resource
output userInfo object = {
  id: salesUser.outputs.userId
  displayName: salesUser.outputs.displayName
  email: salesUser.outputs.mail
}
```

### Multiple User References

```bicep
param teamMembers array = [
  'alice.manager@contoso.com'
  'bob.developer@contoso.com'
  'carol.tester@contoso.com'
]

module teamUsers 'modules/microsoft-graph/users/main.bicep' = [for member in teamMembers: {
  name: 'user-${replace(member, '@', '-at-')}'
  params: {
    userPrincipalName: member
  }
}]
```

## Parameters Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| **userPrincipalName** | `string` | The User Principal Name (UPN) of the existing user. Must be a valid UPN format (e.g., `user@domain.com`). |

## Usage Examples

### Enterprise User Management

```bicep
// Reference key enterprise users
module ceo 'modules/microsoft-graph/users/main.bicep' = {
  name: 'ceo-user'
  params: {
    userPrincipalName: 'ceo@contoso.com'
  }
}

module cto 'modules/microsoft-graph/users/main.bicep' = {
  name: 'cto-user'
  params: {
    userPrincipalName: 'cto@contoso.com'
  }
}

module cfo 'modules/microsoft-graph/users/main.bicep' = {
  name: 'cfo-user'
  params: {
    userPrincipalName: 'cfo@contoso.com'
  }
}

// Create executive group with these users
module executiveGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'executive-group'
  params: {
    displayName: 'Executive Team'
    mailNickname: 'executives'
    memberIds: [
      ceo.outputs.userId
      cto.outputs.userId
      cfo.outputs.userId
    ]
  }
}
```

### Development Team Setup

```bicep
// Define development team members
param devTeamMembers array = [
  'lead.developer@contoso.com'
  'senior.dev1@contoso.com'
  'senior.dev2@contoso.com'
  'junior.dev1@contoso.com'
  'junior.dev2@contoso.com'
  'qa.engineer@contoso.com'
  'devops.engineer@contoso.com'
]

// Reference all team members
module devTeamUsers 'modules/microsoft-graph/users/main.bicep' = [for (member, index) in devTeamMembers: {
  name: 'dev-team-user-${index}'
  params: {
    userPrincipalName: member
  }
}]

// Create development team group
module devTeamGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'dev-team-group'
  params: {
    displayName: 'Development Team'
    mailNickname: 'dev-team'
    description: 'Software Development Team Members'
    memberIds: [for i in range(0, length(devTeamMembers)): devTeamUsers[i].outputs.userId]
  }
}

// Output team information for reporting
output teamSummary object = {
  teamName: 'Development Team'
  memberCount: length(devTeamMembers)
  members: [for i in range(0, length(devTeamMembers)): {
    upn: devTeamUsers[i].outputs.userPrincipalName
    displayName: devTeamUsers[i].outputs.displayName
    jobTitle: devTeamUsers[i].outputs.jobTitle
    mail: devTeamUsers[i].outputs.mail
  }]
}
```

### Application Ownership Assignment

```bicep
// Define application owners
param appOwners array = [
  'app.owner1@contoso.com'
  'app.owner2@contoso.com'
  'backup.owner@contoso.com'
]

// Reference owner users
module ownerUsers 'modules/microsoft-graph/users/main.bicep' = [for owner in appOwners: {
  name: 'owner-${replace(owner, '@', '-at-')}'
  params: {
    userPrincipalName: owner
  }
}]

// Create application with owners
module customerApp 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'customer-application'
  params: {
    displayName: 'Customer Management System'
    description: 'Enterprise customer management application'
    // Note: This assumes the applications module supports owner assignment
    // Check actual module capabilities for ownership management
  }
}

// Output ownership information
output applicationOwnership object = {
  applicationName: 'Customer Management System'
  owners: [for i in range(0, length(appOwners)): {
    userId: ownerUsers[i].outputs.userId
    displayName: ownerUsers[i].outputs.displayName
    email: ownerUsers[i].outputs.mail
    jobTitle: ownerUsers[i].outputs.jobTitle
  }]
}
```

### Department-Based User Groups

```bicep
// Define department structures
param departments object = {
  sales: [
    'sales.manager@contoso.com'
    'sales.rep1@contoso.com'
    'sales.rep2@contoso.com'
    'sales.admin@contoso.com'
  ]
  marketing: [
    'marketing.director@contoso.com'
    'marketing.manager@contoso.com'
    'content.creator@contoso.com'
    'seo.specialist@contoso.com'
  ]
  hr: [
    'hr.director@contoso.com'
    'hr.manager@contoso.com'
    'recruiter1@contoso.com'
    'benefits.admin@contoso.com'
  ]
}

// Reference sales department users
module salesUsers 'modules/microsoft-graph/users/main.bicep' = [for member in departments.sales: {
  name: 'sales-user-${replace(member, '@', '-at-')}'
  params: {
    userPrincipalName: member
  }
}]

// Reference marketing department users
module marketingUsers 'modules/microsoft-graph/users/main.bicep' = [for member in departments.marketing: {
  name: 'marketing-user-${replace(member, '@', '-at-')}'
  params: {
    userPrincipalName: member
  }
}]

// Reference HR department users
module hrUsers 'modules/microsoft-graph/users/main.bicep' = [for member in departments.hr: {
  name: 'hr-user-${replace(member, '@', '-at-')}'
  params: {
    userPrincipalName: member
  }
}]

// Create department groups
module salesGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'sales-department-group'
  params: {
    displayName: 'Sales Department'
    mailNickname: 'sales-dept'
    description: 'All sales department members'
    memberIds: [for i in range(0, length(departments.sales)): salesUsers[i].outputs.userId]
  }
}

module marketingGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'marketing-department-group'
  params: {
    displayName: 'Marketing Department'
    mailNickname: 'marketing-dept'
    description: 'All marketing department members'
    memberIds: [for i in range(0, length(departments.marketing)): marketingUsers[i].outputs.userId]
  }
}

module hrGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'hr-department-group'
  params: {
    displayName: 'Human Resources Department'
    mailNickname: 'hr-dept'
    description: 'All HR department members'
    memberIds: [for i in range(0, length(departments.hr)): hrUsers[i].outputs.userId]
  }
}
```

### Role-Based Access Control (RBAC) Setup

```bicep
// Define role-based user assignments
param rbacAssignments object = {
  globalAdmins: [
    'global.admin1@contoso.com'
    'global.admin2@contoso.com'
  ]
  applicationAdmins: [
    'app.admin1@contoso.com'
    'app.admin2@contoso.com'
  ]
  userAdmins: [
    'user.admin1@contoso.com'
    'user.admin2@contoso.com'
  ]
  helpdesk: [
    'helpdesk.tier1@contoso.com'
    'helpdesk.tier2@contoso.com'
    'helpdesk.supervisor@contoso.com'
  ]
}

// Reference Global Administrator users
module globalAdminUsers 'modules/microsoft-graph/users/main.bicep' = [for admin in rbacAssignments.globalAdmins: {
  name: 'global-admin-${replace(admin, '@', '-at-')}'
  params: {
    userPrincipalName: admin
  }
}]

// Reference Application Administrator users
module appAdminUsers 'modules/microsoft-graph/users/main.bicep' = [for admin in rbacAssignments.applicationAdmins: {
  name: 'app-admin-${replace(admin, '@', '-at-')}'
  params: {
    userPrincipalName: admin
  }
}]

// Reference User Administrator users
module userAdminUsers 'modules/microsoft-graph/users/main.bicep' = [for admin in rbacAssignments.userAdmins: {
  name: 'user-admin-${replace(admin, '@', '-at-')}'
  params: {
    userPrincipalName: admin
  }
}]

// Reference Helpdesk users
module helpdeskUsers 'modules/microsoft-graph/users/main.bicep' = [for user in rbacAssignments.helpdesk: {
  name: 'helpdesk-${replace(user, '@', '-at-')}'
  params: {
    userPrincipalName: user
  }
}]

// Create role-based groups
module globalAdminGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'global-admin-group'
  params: {
    displayName: 'Global Administrators'
    mailNickname: 'global-admins'
    description: 'Global Administrator role members'
    memberIds: [for i in range(0, length(rbacAssignments.globalAdmins)): globalAdminUsers[i].outputs.userId]
  }
}

module appAdminGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'app-admin-group'
  params: {
    displayName: 'Application Administrators'
    mailNickname: 'app-admins'
    description: 'Application Administrator role members'
    memberIds: [for i in range(0, length(rbacAssignments.applicationAdmins)): appAdminUsers[i].outputs.userId]
  }
}

module helpdeskGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'helpdesk-group'
  params: {
    displayName: 'IT Helpdesk Team'
    mailNickname: 'helpdesk'
    description: 'IT Helpdesk support team members'
    memberIds: [for i in range(0, length(rbacAssignments.helpdesk)): helpdeskUsers[i].outputs.userId]
  }
}
```

### Project Team Assignment

```bicep
param projectName string = 'CustomerPortal'
param projectTeam array = [
  'project.manager@contoso.com'
  'lead.architect@contoso.com'
  'senior.developer@contoso.com'
  'ui.designer@contoso.com'
  'qa.lead@contoso.com'
  'business.analyst@contoso.com'
]

// Reference project team members
module projectMembers 'modules/microsoft-graph/users/main.bicep' = [for (member, index) in projectTeam: {
  name: '${toLower(projectName)}-member-${index}'
  params: {
    userPrincipalName: member
  }
}]

// Create project team group
module projectGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: '${toLower(projectName)}-team-group'
  params: {
    displayName: '${projectName} Project Team'
    mailNickname: '${toLower(projectName)}-team'
    description: 'Members of the ${projectName} project team'
    memberIds: [for i in range(0, length(projectTeam)): projectMembers[i].outputs.userId]
  }
}

// Output project team summary
output projectTeamSummary object = {
  projectName: projectName
  teamSize: length(projectTeam)
  projectManager: projectMembers[0].outputs.displayName
  leadArchitect: projectMembers[1].outputs.displayName
  teamMembers: [for i in range(0, length(projectTeam)): {
    role: i == 0 ? 'Project Manager' : i == 1 ? 'Lead Architect' : i == 2 ? 'Senior Developer' : i == 3 ? 'UI Designer' : i == 4 ? 'QA Lead' : 'Business Analyst'
    displayName: projectMembers[i].outputs.displayName
    email: projectMembers[i].outputs.mail
    jobTitle: projectMembers[i].outputs.jobTitle
  }]
}
```

### Guest User Integration

```bicep
// Reference external partner users (guest users)
param partnerUsers array = [
  'partner.contact@partner1.com'
  'consultant@external-firm.com'
  'vendor.rep@supplier.com'
]

// Reference guest users (these would be existing guest users in your tenant)
module guestUsers 'modules/microsoft-graph/users/main.bicep' = [for guest in partnerUsers: {
  name: 'guest-${replace(replace(guest, '@', '-at-'), '.', '-')}'
  params: {
    userPrincipalName: guest
  }
}]

// Create external collaboration group
module partnersGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'external-partners-group'
  params: {
    displayName: 'External Partners'
    mailNickname: 'partners'
    description: 'External partner and consultant access group'
    memberIds: [for i in range(0, length(partnerUsers)): guestUsers[i].outputs.userId]
  }
}
```

### Conditional User References

```bicep
param environment string = 'production'
param includeTestUsers bool = environment != 'production'

// Core team members (always included)
param coreTeam array = [
  'core.admin@contoso.com'
  'core.developer@contoso.com'
]

// Test users (only in non-production)
param testUsers array = [
  'test.user1@contoso.com'
  'test.user2@contoso.com'
]

// Reference core team
module coreTeamUsers 'modules/microsoft-graph/users/main.bicep' = [for member in coreTeam: {
  name: 'core-${replace(member, '@', '-at-')}'
  params: {
    userPrincipalName: member
  }
}]

// Reference test users conditionally
module testTeamUsers 'modules/microsoft-graph/users/main.bicep' = [for member in testUsers: if (includeTestUsers) {
  name: 'test-${replace(member, '@', '-at-')}'
  params: {
    userPrincipalName: member
  }
}]

// Combine users based on environment
var allUserIds = concat(
  [for i in range(0, length(coreTeam)): coreTeamUsers[i].outputs.userId],
  includeTestUsers ? [for i in range(0, length(testUsers)): testTeamUsers[i].outputs.userId] : []
)

// Create environment-specific group
module environmentGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: '${environment}-users-group'
  params: {
    displayName: '${toUpper(environment)} Environment Users'
    mailNickname: '${environment}-users'
    description: 'Users with access to ${environment} environment'
    memberIds: allUserIds
  }
}
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| **resourceId** | `string` | The unique resource ID of the user |
| **userId** | `string` | The user ID (object ID) - same as resourceId |
| **userPrincipalName** | `string` | The User Principal Name (UPN) |
| **displayName** | `string` | The display name of the user |
| **mail** | `string` | The mail address of the user |
| **givenName** | `string` | The given name (first name) of the user |
| **surname** | `string` | The surname (last name) of the user |
| **jobTitle** | `string` | The job title of the user |
| **mobilePhone** | `string` | The mobile phone number of the user |
| **officeLocation** | `string` | The office location of the user |
| **preferredLanguage** | `string` | The preferred language of the user |
| **businessPhones** | `array` | Array of business phone numbers |

## User Principal Name (UPN) Formats

### Standard UPN Format
- **Format**: `username@domain.com`
- **Example**: `john.doe@contoso.com`
- **Use Case**: Standard organizational users

### Guest User UPN Format
- **Format**: `externaluser_domain.com#EXT#@yourtenant.onmicrosoft.com`
- **Example**: `partner_external.com#EXT#@contoso.onmicrosoft.com`
- **Use Case**: External users invited as guests

### Multi-Domain UPN Format
- **Format**: `username@subsidiary.domain.com`
- **Example**: `user@subsidiary.contoso.com`
- **Use Case**: Organizations with multiple verified domains

## Integration Patterns

### With Groups Module
```bicep
// Reference users and add to group
module users 'modules/microsoft-graph/users/main.bicep' = [for upn in userList: {
  name: 'user-${replace(upn, '@', '-at-')}'
  params: { userPrincipalName: upn }
}]

module group 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'team-group'
  params: {
    displayName: 'Team Group'
    memberIds: [for i in range(0, length(userList)): users[i].outputs.userId]
  }
}
```

### With App Role Assignments
```bicep
// Reference user and assign app role
module admin 'modules/microsoft-graph/users/main.bicep' = {
  name: 'admin-user'
  params: { userPrincipalName: 'admin@contoso.com' }
}

module roleAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'admin-role-assignment'
  params: {
    appRoleId: 'admin-role-id'
    principalId: admin.outputs.userId
    resourceId: 'api-service-principal-id'
    principalType: 'User'
  }
}
```

### With Service Principals
```bicep
// Reference users for service principal ownership
module owners 'modules/microsoft-graph/users/main.bicep' = [for owner in ownerUpns: {
  name: 'owner-${replace(owner, '@', '-at-')}'
  params: { userPrincipalName: owner }
}]

// Note: Service principal ownership would depend on servicePrincipals module capabilities
```

## Security Best Practices

### User Verification
- **Validate UPNs**: Ensure User Principal Names are correctly formatted
- **Verify Existence**: Confirm users exist before deployment
- **Access Control**: Only reference users you have legitimate access to
- **Regular Audits**: Periodically review user references and access

### Permission Management
- **Least Privilege**: Only request minimum required user information
- **Scope Limitation**: Limit user property access to what's needed
- **Regular Reviews**: Conduct periodic access reviews for user assignments
- **Documentation**: Maintain clear documentation of user roles and access

### Data Protection
- **Sensitive Information**: Handle user personal information appropriately
- **Compliance**: Ensure compliance with data protection regulations
- **Audit Logging**: Maintain audit trails for user access and assignments
- **Secure References**: Use secure methods for user identification

## Troubleshooting

### Common Issues

1. **User Not Found**
   ```
   Error: User with UPN 'user@domain.com' was not found
   ```
   - Verify the User Principal Name is spelled correctly
   - Ensure the user exists in Azure AD
   - Check if the user account is active (not disabled)

2. **Invalid UPN Format**
   ```
   Error: Invalid User Principal Name format
   ```
   - Ensure UPN follows the format: `username@domain.com`
   - Verify domain is correctly spelled
   - Check for hidden characters or spaces

3. **Permission Denied**
   ```
   Error: Insufficient privileges to read user information
   ```
   - Ensure you have User.Read.All or Directory.Read.All permissions
   - Check if the user is in a restricted administrative unit
   - Verify service principal has correct permissions

4. **Guest User Issues**
   ```
   Error: Guest user UPN not recognized
   ```
   - Use the transformed UPN format for guest users
   - Check if guest user has accepted invitation
   - Verify guest user is properly synchronized

### Debugging Steps

1. **Verify User Existence**
   ```bash
   # Check if user exists
   az ad user show --id "user@domain.com"
   
   # List users (if you have permissions)
   az ad user list --query "[?userPrincipalName=='user@domain.com']"
   ```

2. **Check Permissions**
   ```bash
   # Check current user permissions
   az ad signed-in-user show --query "userPrincipalName"
   
   # List directory roles
   az ad signed-in-user list-owned-objects --type directoryRole
   ```

3. **Validate UPN Format**
   ```bash
   # Search for users with similar names
   az ad user list --query "[?contains(userPrincipalName, 'searchterm')]"
   
   # Check domain verification
   az ad domain list --query "[].name"
   ```

4. **Test with PowerShell**
   ```powershell
   # Connect and test user lookup
   Connect-MgGraph -Scopes "User.Read.All"
   Get-MgUser -Filter "userPrincipalName eq 'user@domain.com'"
   ```

## Related Resources

- [Microsoft Graph Users API](https://docs.microsoft.com/en-us/graph/api/resources/user)
- [Azure AD User Management](https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/)
- [User Principal Names in Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/plan-connect-userprincipalname)
- [Guest User Access in Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/external-identities/)
- [Microsoft Graph Permissions Reference](https://docs.microsoft.com/en-us/graph/permissions-reference)

## Contributing

This module is part of the Microsoft Graph Bicep module collection. For contributions, issues, or feature requests, please refer to the main repository guidelines.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
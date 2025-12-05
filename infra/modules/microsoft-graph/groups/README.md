# Microsoft Graph Groups Module

[![Bicep Version](https://img.shields.io/badge/Bicep->=0.21.0-blue.svg)](https://github.com/Azure/bicep)
[![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-v1.0-green.svg)](https://docs.microsoft.com/en-us/graph/)

This Bicep module creates and configures Azure AD (Entra ID) groups using the Microsoft Graph Bicep extension v1.0. Groups are fundamental building blocks for organizing users, devices, and other resources in Azure AD, enabling efficient access management and collaboration.

## Overview

Azure AD groups provide a flexible way to manage collections of users, devices, and other groups for access control, collaboration, and administrative purposes. This module supports creating security groups, Microsoft 365 groups, dynamic groups, and role-assignable groups with comprehensive configuration options.

### Key Features

- ✅ **Multiple Group Types**: Security groups, Microsoft 365 groups, and distribution groups
- ✅ **Dynamic Membership**: Automatic membership based on user or device attributes
- ✅ **Role Assignment**: Groups that can be assigned to Azure AD roles
- ✅ **Access Management**: Integration with conditional access and PIM
- ✅ **Collaboration**: Microsoft 365 integration with Teams, SharePoint, and Exchange
- ✅ **Enterprise Security**: Advanced security controls and compliance features
- ✅ **Lifecycle Management**: Automated group expiration and renewal policies
- ✅ **Multi-Geo Support**: Geographic data residency compliance

## Prerequisites

- Azure CLI or Azure PowerShell
- Bicep CLI (version 0.21.0 or later)
- Microsoft Graph Bicep extension v1.0
- Appropriate Azure AD permissions (Groups Administrator, User Administrator, or Global Administrator)

## Installation

Install the Microsoft Graph Bicep extension:

```bash
# Install the extension
az extension add --name microsoft-graph

# Verify installation
az extension list --query "[?name=='microsoft-graph']"
```

## Quick Start

### Basic Security Group

```bicep
module securityGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'basic-security-group'
  params: {
    displayName: 'IT Administrators'
    mailNickname: 'it-admins'
    groupDescription: 'Security group for IT administrative staff'
    securityEnabled: true
    mailEnabled: false
  }
}
```

### Microsoft 365 Group

```bicep
module m365Group 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'microsoft365-group'
  params: {
    displayName: 'Marketing Team'
    mailNickname: 'marketing-team'
    groupDescription: 'Collaboration group for marketing team'
    mailEnabled: true
    securityEnabled: true
    groupTypes: ['Unified']
    visibility: 'Public'
  }
}
```

## Parameters Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| **displayName** | `string` | The display name for the group. Must be unique within the organization. Maximum 256 characters. |
| **mailNickname** | `string` | The mail alias for the group. Must be unique within the organization. Only alphanumeric characters and hyphens allowed. |

### Core Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **groupDescription** | `string` | `''` | An optional description for the group. Maximum 1024 characters. |
| **mailEnabled** | `bool` | `false` | Specifies whether the group is mail-enabled. Required for Microsoft 365 groups. |
| **securityEnabled** | `bool` | `true` | Specifies whether the group is a security group. |
| **groupTypes** | `array` | `[]` | Specifies the group type. Use `['Unified']` for Microsoft 365 groups. |

### Access Control and Visibility

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **visibility** | `string` | `'Private'` | Specifies the group visibility. Valid values: `Private`, `Public`, `HiddenMembership`. |
| **isAssignableToRole** | `bool` | `false` | Indicates whether this group can be assigned to an Azure AD role. Cannot be changed after creation. |
| **classification** | `string` | `''` | A classification for the group (such as low, medium or high business impact). |

### Dynamic Membership

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **membershipRule** | `string` | `''` | The rule that determines members for dynamic groups. Only valid for security groups. |
| **membershipRuleProcessingState** | `string` | `'On'` | Indicates whether dynamic membership processing is on or paused. Valid values: `On`, `Paused`. |

### Localization and Regional Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **preferredLanguage** | `string` | `''` | The preferred language for a Microsoft 365 group. Should follow ISO 639-1 Code (e.g., `en-US`). |
| **preferredDataLocation** | `string` | `''` | The preferred data location for the group. Must be a valid country code. |
| **theme** | `string` | `''` | Specifies a Microsoft 365 group's color theme. Valid values: `Teal`, `Purple`, `Green`, `Blue`, `Pink`, `Orange`, `Red`. |

### Management and Ownership

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **ownerIds** | `array` | `[]` | Object IDs of users who will be owners of the group. |
| **memberIds** | `array` | `[]` | Object IDs of users who will be members of the group. |
| **isManagementRestricted** | `bool` | `false` | Indicates whether the group creation and management is restricted to administrators. |

### Metadata and Compliance

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **tags** | `array` | `[]` | Custom tags for the group for organizational and compliance purposes. |
| **notes** | `string` | `''` | Free text field to capture information about the group. |

### Microsoft 365 Specific Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **allowExternalSenders** | `bool` | `false` | Indicates if people external to the organization can send messages to the group. |
| **autoSubscribeNewMembers** | `bool` | `false` | Indicates if new members added to the group will be auto-subscribed to receive email notifications. |
| **hideFromAddressLists** | `bool` | `false` | True if the group is not displayed in certain parts of the Outlook UI. |
| **hideFromOutlookClients** | `bool` | `false` | True if the group is not displayed in Outlook clients. |

## Usage Examples

### Enterprise Security Group with Owners

```bicep
module enterpriseSecurityGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'enterprise-security-group'
  params: {
    displayName: 'Global Administrators'
    mailNickname: 'global-admins'
    groupDescription: 'Global administrators with full tenant access rights'
    securityEnabled: true
    mailEnabled: false
    isAssignableToRole: true
    visibility: 'Private'
    classification: 'High'
    
    // Assign owners
    ownerIds: [
      '11111111-1111-1111-1111-111111111111'  // IT Director
      '22222222-2222-2222-2222-222222222222'  // Security Lead
    ]
    
    // Initial members
    memberIds: [
      '33333333-3333-3333-3333-333333333333'  // Admin User 1
      '44444444-4444-4444-4444-444444444444'  // Admin User 2
    ]
    
    tags: ['Security', 'Critical', 'Privileged-Access']
    notes: 'High-privilege security group for global tenant administration'
  }
}
```

### Microsoft 365 Collaboration Group

```bicep
module collaborationGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'collaboration-group'
  params: {
    displayName: 'Product Development Team'
    mailNickname: 'product-dev-team'
    groupDescription: 'Cross-functional team for product development initiatives'
    mailEnabled: true
    securityEnabled: true
    groupTypes: ['Unified']
    visibility: 'Public'
    classification: 'Medium'
    
    // Microsoft 365 specific settings
    preferredLanguage: 'en-US'
    preferredDataLocation: 'NAM'
    theme: 'Blue'
    allowExternalSenders: false
    autoSubscribeNewMembers: true
    hideFromAddressLists: false
    hideFromOutlookClients: false
    
    // Team leads as owners
    ownerIds: [
      '55555555-5555-5555-5555-555555555555'  // Product Manager
      '66666666-6666-6666-6666-666666666666'  // Tech Lead
    ]
    
    tags: ['Collaboration', 'Product-Development', 'Cross-Functional']
    notes: 'Microsoft 365 group with integrated Teams, SharePoint, and Exchange capabilities'
  }
}
```

### Dynamic Security Group

```bicep
module dynamicGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'dynamic-security-group'
  params: {
    displayName: 'Sales Department - Dynamic'
    mailNickname: 'sales-dept-dynamic'
    groupDescription: 'Dynamic group for all sales department employees'
    securityEnabled: true
    mailEnabled: false
    visibility: 'Private'
    
    // Dynamic membership rule
    membershipRule: '(user.department -eq "Sales") and (user.accountEnabled -eq true)'
    membershipRuleProcessingState: 'On'
    
    // Owner for group management
    ownerIds: [
      '77777777-7777-7777-7777-777777777777'  // Sales Director
    ]
    
    tags: ['Dynamic', 'Sales', 'Department-Based']
    notes: 'Automatically managed group based on user department attribute'
  }
}
```

### Regional Microsoft 365 Group

```bicep
module regionalGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'regional-group'
  params: {
    displayName: 'EMEA Marketing Team'
    mailNickname: 'emea-marketing'
    groupDescription: 'Marketing team for Europe, Middle East, and Africa region'
    mailEnabled: true
    securityEnabled: true
    groupTypes: ['Unified']
    visibility: 'Public'
    
    // Regional settings
    preferredLanguage: 'en-GB'
    preferredDataLocation: 'EUR'
    theme: 'Green'
    classification: 'General'
    
    // External collaboration settings
    allowExternalSenders: true
    autoSubscribeNewMembers: true
    
    tags: ['Regional', 'EMEA', 'Marketing', 'External-Collaboration']
    notes: 'Regional marketing group with external collaboration enabled'
  }
}
```

### Multi-Environment Group with Conditional Logic

```bicep
param environment string = 'production'
param departmentName string = 'Finance'

module departmentGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: '${toLower(departmentName)}-${environment}-group'
  params: {
    displayName: '${departmentName} - ${toUpper(environment)}'
    mailNickname: '${toLower(departmentName)}-${environment}'
    groupDescription: '${departmentName} department group for ${environment} environment'
    securityEnabled: true
    mailEnabled: environment == 'production'
    groupTypes: environment == 'production' ? ['Unified'] : []
    visibility: environment == 'production' ? 'Private' : 'Public'
    classification: environment == 'production' ? 'High' : 'Low'
    
    // Role assignment only in production
    isAssignableToRole: environment == 'production'
    
    tags: [
      'Department:${departmentName}'
      'Environment:${environment}'
      'Auto-Generated'
    ]
    
    notes: 'Environment-specific ${departmentName} department group managed via Bicep'
  }
}
```

### Device Management Group

```bicep
module deviceGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'device-management-group'
  params: {
    displayName: 'Corporate Devices - Windows'
    mailNickname: 'corporate-devices-windows'
    groupDescription: 'Dynamic group for corporate Windows devices'
    securityEnabled: true
    mailEnabled: false
    visibility: 'Private'
    
    // Dynamic membership for devices
    membershipRule: '(device.deviceOSType -eq "Windows") and (device.managementType -eq "MDM")'
    membershipRuleProcessingState: 'On'
    
    // Device administrators as owners
    ownerIds: [
      '88888888-8888-8888-8888-888888888888'  // Device Admin 1
      '99999999-9999-9999-9999-999999999999'  // Device Admin 2
    ]
    
    tags: ['Device-Management', 'Windows', 'MDM', 'Corporate']
    notes: 'Dynamic group for managing corporate Windows devices through Intune'
  }
}
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| **resourceId** | `string` | The resource ID of the group |
| **groupId** | `string` | The unique identifier (object ID) of the group |
| **displayName** | `string` | The display name of the group |
| **mailNickname** | `string` | The mail nickname of the group |
| **mailEnabled** | `bool` | Whether the group is mail-enabled |
| **securityEnabled** | `bool` | Whether the group is security-enabled |
| **groupTypes** | `array` | The types assigned to the group |
| **visibility** | `string` | The visibility of the group |
| **isAssignableToRole** | `bool` | Whether the group can be assigned to roles |
| **classification** | `string` | The classification of the group |
| **membershipRule** | `string` | The dynamic membership rule (if applicable) |
| **membershipRuleProcessingState** | `string` | The processing state of the membership rule |

## Group Types and Use Cases

### Security Groups
- **Purpose**: Access control and permissions management
- **Key Features**: Can be assigned to resources, applications, and roles
- **Best For**: RBAC, conditional access policies, application permissions

### Microsoft 365 Groups (Unified Groups)
- **Purpose**: Collaboration and productivity
- **Key Features**: Integrated with Teams, SharePoint, Exchange, Planner
- **Best For**: Team collaboration, project groups, department groups

### Distribution Groups
- **Purpose**: Email distribution lists
- **Key Features**: Email-enabled but not security-enabled
- **Best For**: Mailing lists, announcements, newsletters

### Dynamic Groups
- **Purpose**: Automatic membership management
- **Key Features**: Rule-based membership using user/device attributes
- **Best For**: Department groups, location-based groups, device collections

## Security Best Practices

### Group Management
- **Principle of Least Privilege**: Only grant necessary permissions to groups
- **Regular Access Reviews**: Implement periodic reviews of group memberships
- **Owner Assignment**: Always assign responsible owners for group management
- **Classification**: Use classification to indicate data sensitivity levels

### Dynamic Groups
- **Rule Testing**: Test membership rules in non-production environments first
- **Monitoring**: Monitor dynamic group membership changes and processing
- **Attribute Reliability**: Ensure user attributes used in rules are reliable and maintained

### Role-Assignable Groups
- **Limited Use**: Only create role-assignable groups when necessary
- **Enhanced Security**: Apply additional security controls and monitoring
- **Documentation**: Maintain detailed documentation of role assignments

### Microsoft 365 Groups
- **External Sharing**: Carefully configure external sharing settings
- **Data Location**: Consider data residency requirements for global organizations
- **Lifecycle Management**: Implement group expiration and renewal policies

## Troubleshooting

### Common Issues

1. **Group Creation Fails**
   ```
   Error: A group with the specified mail nickname already exists
   ```
   - Verify the mail nickname is unique across the organization
   - Check soft-deleted groups that may be holding the nickname

2. **Dynamic Group Not Updating**
   ```
   Warning: Dynamic group membership not processing
   ```
   - Verify the membership rule syntax is correct
   - Check that the processing state is set to "On"
   - Ensure referenced user attributes exist and are populated

3. **Role Assignment Fails**
   ```
   Error: Cannot assign role to group
   ```
   - Verify the group has `isAssignableToRole` set to true
   - Check that you have sufficient permissions for role assignment
   - Ensure the role supports group assignment

### Debugging Steps

1. **Verify Prerequisites**
   ```bash
   # Check Azure AD permissions
   az ad signed-in-user show --query "userPrincipalName"
   
   # List existing groups
   az ad group list --filter "displayName eq 'Your Group Name'"
   ```

2. **Test Dynamic Group Rules**
   ```bash
   # Validate membership rule syntax
   az ad group create --display-name "Test Group" --mail-nickname "test" \
     --membership-rule "(user.department -eq \"Sales\")" --query "id"
   ```

3. **Monitor Group Health**
   ```bash
   # Check group details
   az ad group show --group <group-id>
   
   # List group members
   az ad group member list --group <group-id>
   
   # List group owners
   az ad group owner list --group <group-id>
   ```

## Related Resources

- [Microsoft Graph Groups API](https://docs.microsoft.com/en-us/graph/api/resources/group)
- [Azure AD Groups Overview](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-groups-view-azure-portal)
- [Dynamic Group Membership Rules](https://docs.microsoft.com/en-us/azure/active-directory/enterprise-users/groups-dynamic-membership)
- [Microsoft 365 Groups](https://docs.microsoft.com/en-us/microsoft-365/admin/create-groups/office-365-groups)
- [Azure AD Role-Assignable Groups](https://docs.microsoft.com/en-us/azure/active-directory/roles/groups-concept)

## Contributing

This module is part of the Microsoft Graph Bicep module collection. For contributions, issues, or feature requests, please refer to the main repository guidelines.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
# Microsoft Graph App Role Assignment Module

[![Bicep Version](https://img.shields.io/badge/Bicep->=0.21.0-blue.svg)](https://github.com/Azure/bicep)
[![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-v1.0-green.svg)](https://docs.microsoft.com/en-us/graph/)

This Bicep module creates and manages app role assignments in Azure AD (Entra ID) using the Microsoft Graph Bicep extension v1.0. App role assignments are fundamental for implementing role-based access control (RBAC) in applications, allowing you to grant specific application permissions to users, groups, or service principals.

## Overview

App role assignments in Azure AD enable fine-grained permission management by assigning specific application roles to principals (users, groups, or service principals). This module simplifies the process of creating these assignments through Infrastructure as Code, ensuring consistent and auditable permission management.

### Key Features

- ✅ **Multi-Principal Support**: Assign roles to users, groups, or service principals
- ✅ **Enterprise RBAC**: Implement role-based access control for applications
- ✅ **Permission Management**: Granular control over application permissions
- ✅ **Audit Trail**: Full deployment history and tracking
- ✅ **Security Controls**: Validation and compliance features
- ✅ **API Integration**: Direct Microsoft Graph API integration
- ✅ **Batch Operations**: Support for multiple role assignments
- ✅ **Cross-Application**: Assign roles across different applications

## Prerequisites

- Azure CLI or Azure PowerShell
- Bicep CLI (version 0.21.0 or later)
- Microsoft Graph Bicep extension v1.0
- Appropriate Azure AD permissions (Application Administrator, Privileged Role Administrator, or Global Administrator)

## Installation

Install the Microsoft Graph Bicep extension:

```bash
# Install the extension
az extension add --name microsoft-graph

# Verify installation
az extension list --query "[?name=='microsoft-graph']"
```

## Quick Start

### Basic App Role Assignment

```bicep
module basicRoleAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'basic-role-assignment'
  params: {
    appRoleId: '00000000-0000-0000-0000-000000000001'
    principalId: '12345678-1234-1234-1234-123456789012'
    resourceId: 'fedcba98-7654-3210-fedc-ba9876543210'
    resourceDisplayName: 'My API Application'
    principalType: 'User'
  }
}
```

### Service Principal Role Assignment

```bicep
module servicePrincipalAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'service-principal-assignment'
  params: {
    appRoleId: 'df021288-bdef-4463-88db-98f22de89214'
    principalId: 'abcdef12-3456-7890-abcd-ef1234567890'
    resourceId: 'fedcba98-7654-3210-fedc-ba9876543210'
    resourceDisplayName: 'Enterprise API Gateway'
    principalType: 'ServicePrincipal'
  }
}
```

## Parameters Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| **appRoleId** | `string` | The unique identifier of the app role being assigned. Must be a valid GUID from the target application's app roles. |
| **principalId** | `string` | The object ID of the principal (user, group, or service principal) receiving the role assignment. |
| **resourceId** | `string` | The object ID of the service principal that defines the app role (typically the API or application service principal). |
| **resourceDisplayName** | `string` | The display name of the resource application for documentation and tracking purposes. |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **principalType** | `string` | `'ServicePrincipal'` | Type of principal receiving the role. Valid values: `User`, `Group`, `ServicePrincipal`. |

## Usage Examples

### Enterprise User Role Assignment

```bicep
// Assign a specific application role to a user
module userRoleAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'user-api-access-assignment'
  params: {
    appRoleId: '62e90394-69f5-4237-9190-012177145e10'  // API.Read role
    principalId: '11111111-1111-1111-1111-111111111111'  // User object ID
    resourceId: '22222222-2222-2222-2222-222222222222'   // API service principal ID
    resourceDisplayName: 'Customer Management API'
    principalType: 'User'
  }
}
```

### Group-Based Role Assignment

```bicep
// Assign application role to a security group
module groupRoleAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'group-admin-assignment'
  params: {
    appRoleId: 'c79f8feb-a9db-4090-85f9-90d820caa0eb'  // Admin role
    principalId: '33333333-3333-3333-3333-333333333333'  // Security group object ID
    resourceId: '44444444-4444-4444-4444-444444444444'   // Application service principal
    resourceDisplayName: 'HR Management System'
    principalType: 'Group'
  }
}
```

### Service Principal to Service Principal Assignment

```bicep
// Service principal accessing another service principal's roles
module serviceToServiceAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'service-to-service-assignment'
  params: {
    appRoleId: '741f803b-c850-494e-b5df-cde7c675a1ca'  // Service.ReadWrite
    principalId: '55555555-5555-5555-5555-555555555555'  // Client service principal
    resourceId: '66666666-6666-6666-6666-666666666666'   // API service principal
    resourceDisplayName: 'Payment Processing API'
    principalType: 'ServicePrincipal'
  }
}
```

### Microsoft Graph API Permissions

```bicep
// Assign Microsoft Graph permissions to an application
module graphPermissionAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'graph-permission-assignment'
  params: {
    appRoleId: '1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9'  // Application.ReadWrite.All
    principalId: '77777777-7777-7777-7777-777777777777'  // App service principal
    resourceId: '00000003-0000-0000-c000-000000000000'   // Microsoft Graph service principal
    resourceDisplayName: 'Microsoft Graph'
    principalType: 'ServicePrincipal'
  }
}
```

### Multiple Role Assignments with Loop

```bicep
// Define multiple role assignments for different environments
param roleAssignments array = [
  {
    appRoleId: '62e90394-69f5-4237-9190-012177145e10'
    principalId: '11111111-1111-1111-1111-111111111111'
    resourceId: '22222222-2222-2222-2222-222222222222'
    resourceDisplayName: 'Customer API'
    principalType: 'User'
    description: 'Customer API Read access for sales team'
  }
  {
    appRoleId: 'c79f8feb-a9db-4090-85f9-90d820caa0eb'
    principalId: '33333333-3333-3333-3333-333333333333'
    resourceId: '22222222-2222-2222-2222-222222222222'
    resourceDisplayName: 'Customer API'
    principalType: 'Group'
    description: 'Customer API Admin access for IT group'
  }
]

// Create role assignments using loops
module multipleRoleAssignments 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = [for (assignment, index) in roleAssignments: {
  name: 'role-assignment-${index}'
  params: {
    appRoleId: assignment.appRoleId
    principalId: assignment.principalId
    resourceId: assignment.resourceId
    resourceDisplayName: assignment.resourceDisplayName
    principalType: assignment.principalType
  }
}]
```

### Environment-Specific Assignments

```bicep
param environment string = 'production'
param apiServicePrincipalId string = '88888888-8888-8888-8888-888888888888'

// Different permissions based on environment
module environmentRoleAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'environment-role-assignment'
  params: {
    appRoleId: environment == 'production' ? 'read-only-role-id' : 'full-access-role-id'
    principalId: '99999999-9999-9999-9999-999999999999'
    resourceId: apiServicePrincipalId
    resourceDisplayName: 'Data Processing API - ${toUpper(environment)}'
    principalType: 'ServicePrincipal'
  }
}
```

### Cross-Tenant B2B Role Assignment

```bicep
// Assign roles to external users in B2B scenarios
module b2bRoleAssignment 'modules/microsoft-graph/appRoleAssignedTo/main.bicep' = {
  name: 'b2b-role-assignment'
  params: {
    appRoleId: '2d05a661-f651-4d57-a595-489c91eda336'  // Partner.Read role
    principalId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'  // External user object ID
    resourceId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'   // Partner portal service principal
    resourceDisplayName: 'Partner Portal Application'
    principalType: 'User'
  }
}
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| **resourceId** | `string` | The unique resource ID of the app role assignment |
| **appRoleId** | `string` | The ID of the app role that was assigned |
| **principalId** | `string` | The object ID of the principal that received the role |
| **assignedResourceId** | `string` | The object ID of the resource that defines the app role |
| **principalType** | `string` | The type of principal that received the assignment |

## Common App Role Scenarios

### Microsoft Graph Permissions

Common Microsoft Graph app roles for service principals:

```bicep
// Directory read permissions
param directoryReadRoleId string = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'  // Directory.Read.All

// User management permissions  
param userReadWriteRoleId string = '741f803b-c850-494e-b5df-cde7c675a1ca'  // User.ReadWrite.All

// Application management permissions
param appReadWriteRoleId string = '1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9'  // Application.ReadWrite.All
```

### Custom Application Roles

Example custom app roles in your application:

```bicep
// Custom API roles
param apiReadRoleId string = '62e90394-69f5-4237-9190-012177145e10'     // API.Read
param apiWriteRoleId string = 'c79f8feb-a9db-4090-85f9-90d820caa0eb'    // API.Write
param apiAdminRoleId string = '2d05a661-f651-4d57-a595-489c91eda336'    // API.Admin
```

## Security Best Practices

### Permission Management
- **Principle of Least Privilege**: Only assign the minimum required permissions
- **Regular Audits**: Implement periodic reviews of role assignments
- **Time-Bound Access**: Consider implementing temporary role assignments where possible
- **Separation of Duties**: Avoid combining sensitive permissions in single assignments

### Monitoring and Compliance
- **Assignment Tracking**: Maintain detailed logs of all role assignments
- **Change Management**: Require approval workflows for sensitive role assignments
- **Automated Validation**: Implement checks to prevent over-privileged assignments
- **Compliance Reporting**: Generate regular reports on permission assignments

### Service Principal Security
- **Certificate-Based Authentication**: Use certificates instead of client secrets where possible
- **Rotation Policies**: Implement regular credential rotation for service principals
- **Scope Limitation**: Limit service principal permissions to specific resources
- **Environment Isolation**: Use different service principals for different environments

## Troubleshooting

### Common Issues

1. **Assignment Already Exists**
   ```
   Error: App role assignment already exists for this principal
   ```
   - Check existing assignments using Azure portal or PowerShell
   - Remove duplicate assignments before creating new ones

2. **Invalid App Role ID**
   ```
   Error: App role not found for the given ID
   ```
   - Verify the app role exists in the target application
   - Check the application manifest for correct role IDs

3. **Insufficient Permissions**
   ```
   Error: Insufficient privileges to complete the operation
   ```
   - Ensure you have Application Administrator or higher privileges
   - Verify the service principal has consent for the required permissions

4. **Principal Not Found**
   ```
   Error: Principal not found
   ```
   - Verify the principal object ID exists in Azure AD
   - Check if the principal is in the correct tenant

### Debugging Steps

1. **Verify Prerequisites**
   ```bash
   # Check current user permissions
   az ad signed-in-user show --query "userPrincipalName"
   
   # List available app roles for an application
   az ad app show --id <application-id> --query "appRoles"
   ```

2. **Validate Parameters**
   ```bash
   # Check if principal exists
   az ad user show --id <principal-id>
   az ad group show --id <principal-id>
   az ad sp show --id <principal-id>
   
   # Check if resource service principal exists
   az ad sp show --id <resource-id>
   ```

3. **List Existing Assignments**
   ```bash
   # List all app role assignments for a principal
   az ad sp show --id <principal-id> --query "appRoleAssignments"
   
   # List assignments for a specific resource
   az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/<resource-id>/appRoleAssignedTo"
   ```

## Related Resources

- [Microsoft Graph App Role Assignments API](https://docs.microsoft.com/en-us/graph/api/resources/approleassignment)
- [Azure AD Application Roles](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-add-app-roles-in-azure-ad-apps)
- [Microsoft Graph Permissions Reference](https://docs.microsoft.com/en-us/graph/permissions-reference)
- [Azure AD Service Principals](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Role-Based Access Control Best Practices](https://docs.microsoft.com/en-us/azure/role-based-access-control/best-practices)

## Contributing

This module is part of the Microsoft Graph Bicep module collection. For contributions, issues, or feature requests, please refer to the main repository guidelines.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
/*
  Test deployment for Microsoft Graph App Role Assignments Module
  
  This file demonstrates comprehensive usage patterns for app role assignments
  including user assignments, group assignments, service principal assignments,
  Microsoft Graph permissions, and batch operations.
  
  Prerequisites:
  - Microsoft Graph Bicep extension v1.0 installed
  - Appropriate Azure AD permissions (Application Administrator or higher)
  - Valid app role IDs from target applications
  - Valid principal object IDs (users, groups, service principals)
  
  Usage:
  az deployment group create \
    --resource-group myResourceGroup \
    --template-file main.test.bicep \
    --parameters @test.parameters.json
*/

targetScope = 'resourceGroup'

// ========== PARAMETERS ==========

// App Role IDs - Replace with actual role IDs from your applications
@description('App role ID for API read access')
param apiReadRoleId string = '62e90394-69f5-4237-9190-012177145e10'

@description('App role ID for API write access')
param apiWriteRoleId string = 'c79f8feb-a9db-4090-85f9-90d820caa0eb'

@description('App role ID for administrative access')
param apiAdminRoleId string = '2d05a661-f651-4d57-a595-489c91eda336'

@description('Microsoft Graph Directory.Read.All permission')
param graphDirectoryReadRoleId string = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'

@description('Microsoft Graph User.ReadWrite.All permission')
param graphUserReadWriteRoleId string = '741f803b-c850-494e-b5df-cde7c675a1ca'

// Principal IDs - Replace with actual object IDs from your Azure AD
@description('Service principal object ID for API client application')
param apiClientServicePrincipalId string = '11111111-1111-1111-1111-111111111111'

@description('Service principal object ID for background service')
param backgroundServicePrincipalId string = '22222222-2222-2222-2222-222222222222'

@description('User object ID for API administrator')
param adminUserId string = '33333333-3333-3333-3333-333333333333'

@description('User object ID for regular API user')
param regularUserId string = '44444444-4444-4444-4444-444444444444'

@description('Security group object ID for API developers')
param developerGroupId string = '55555555-5555-5555-5555-555555555555'

@description('Security group object ID for API support team')
param supportGroupId string = '66666666-6666-6666-6666-666666666666'

// Resource IDs - Replace with actual service principal IDs
@description('Target API application service principal ID')
param targetApiServicePrincipalId string = '77777777-7777-7777-7777-777777777777'

@description('Microsoft Graph service principal ID (constant)')
param microsoftGraphServicePrincipalId string = '00000003-0000-0000-c000-000000000000'

// Environment and metadata parameters
@description('Environment name for resource naming')
param environment string = 'test'

@description('Application name for display purposes')
param applicationName string = 'Customer Management API'

// ========== SCENARIO 1: SERVICE PRINCIPAL ASSIGNMENTS ==========

// Scenario 1.1: API Client Service Principal with Read Access
module apiClientReadAssignment '../main.bicep' = {
  name: 'api-client-read-${environment}'
  params: {
    appRoleId: apiReadRoleId
    principalId: apiClientServicePrincipalId
    resourceId: targetApiServicePrincipalId
    resourceDisplayName: '${applicationName} (${environment})'
    principalType: 'ServicePrincipal'
  }
}

// Scenario 1.2: Background Service with Write Access
module backgroundServiceWriteAssignment '../main.bicep' = {
  name: 'background-service-write-${environment}'
  params: {
    appRoleId: apiWriteRoleId
    principalId: backgroundServicePrincipalId
    resourceId: targetApiServicePrincipalId
    resourceDisplayName: '${applicationName} (${environment})'
    principalType: 'ServicePrincipal'
  }
}

// Scenario 1.3: Service Principal with Microsoft Graph Permissions
module graphDirectoryPermission '../main.bicep' = {
  name: 'graph-directory-read-${environment}'
  params: {
    appRoleId: graphDirectoryReadRoleId
    principalId: apiClientServicePrincipalId
    resourceId: microsoftGraphServicePrincipalId
    resourceDisplayName: 'Microsoft Graph'
    principalType: 'ServicePrincipal'
  }
}

// ========== SCENARIO 2: USER ASSIGNMENTS ==========

// Scenario 2.1: Administrator User with Full Access
module adminUserAssignment '../main.bicep' = {
  name: 'admin-user-assignment-${environment}'
  params: {
    appRoleId: apiAdminRoleId
    principalId: adminUserId
    resourceId: targetApiServicePrincipalId
    resourceDisplayName: '${applicationName} (${environment})'
    principalType: 'User'
  }
}

// Scenario 2.2: Regular User with Read Access
module regularUserAssignment '../main.bicep' = {
  name: 'regular-user-assignment-${environment}'
  params: {
    appRoleId: apiReadRoleId
    principalId: regularUserId
    resourceId: targetApiServicePrincipalId
    resourceDisplayName: '${applicationName} (${environment})'
    principalType: 'User'
  }
}

// ========== SCENARIO 3: GROUP ASSIGNMENTS ==========

// Scenario 3.1: Developer Group with Write Access
module developerGroupAssignment '../main.bicep' = {
  name: 'developer-group-assignment-${environment}'
  params: {
    appRoleId: apiWriteRoleId
    principalId: developerGroupId
    resourceId: targetApiServicePrincipalId
    resourceDisplayName: '${applicationName} (${environment})'
    principalType: 'Group'
  }
}

// Scenario 3.2: Support Group with Read Access
module supportGroupAssignment '../main.bicep' = {
  name: 'support-group-assignment-${environment}'
  params: {
    appRoleId: apiReadRoleId
    principalId: supportGroupId
    resourceId: targetApiServicePrincipalId
    resourceDisplayName: '${applicationName} (${environment})'
    principalType: 'Group'
  }
}

// ========== SCENARIO 4: BATCH ASSIGNMENTS ==========

// Define multiple role assignments for batch processing
var batchRoleAssignments = [
  {
    name: 'api-client-read'
    appRoleId: apiReadRoleId
    principalId: apiClientServicePrincipalId
    principalType: 'ServicePrincipal'
    description: 'API client read access'
  }
  {
    name: 'background-write'
    appRoleId: apiWriteRoleId
    principalId: backgroundServicePrincipalId
    principalType: 'ServicePrincipal'
    description: 'Background service write access'
  }
  {
    name: 'admin-full-access'
    appRoleId: apiAdminRoleId
    principalId: adminUserId
    principalType: 'User'
    description: 'Administrator full access'
  }
  {
    name: 'developer-group-write'
    appRoleId: apiWriteRoleId
    principalId: developerGroupId
    principalType: 'Group'
    description: 'Developer group write access'
  }
]

// Create batch assignments using array iteration
module batchAssignments '../main.bicep' = [for (assignment, index) in batchRoleAssignments: {
  name: 'batch-${assignment.name}-${environment}-${index}'
  params: {
    appRoleId: assignment.appRoleId
    principalId: assignment.principalId
    resourceId: targetApiServicePrincipalId
    resourceDisplayName: '${applicationName} (${environment})'
    principalType: assignment.principalType
  }
}]

// ========== SCENARIO 5: CONDITIONAL ASSIGNMENTS ==========

// Environment-specific role assignment
module conditionalAssignment '../main.bicep' = if (environment == 'production') {
  name: 'production-only-assignment'
  params: {
    appRoleId: apiAdminRoleId
    principalId: adminUserId
    resourceId: targetApiServicePrincipalId
    resourceDisplayName: '${applicationName} (PRODUCTION)'
    principalType: 'User'
  }
}

// Microsoft Graph permission based on environment
module conditionalGraphPermission '../main.bicep' = if (environment != 'development') {
  name: 'graph-user-permission-${environment}'
  params: {
    appRoleId: graphUserReadWriteRoleId
    principalId: backgroundServicePrincipalId
    resourceId: microsoftGraphServicePrincipalId
    resourceDisplayName: 'Microsoft Graph'
    principalType: 'ServicePrincipal'
  }
}

// ========== OUTPUTS ==========

@description('Service Principal Assignments Information')
output servicePrincipalAssignments object = {
  apiClientRead: {
    resourceId: apiClientReadAssignment.outputs.resourceId
    appRoleId: apiClientReadAssignment.outputs.appRoleId
    principalId: apiClientReadAssignment.outputs.principalId
    principalType: apiClientReadAssignment.outputs.principalType
    assignedResourceId: apiClientReadAssignment.outputs.assignedResourceId
  }
  backgroundServiceWrite: {
    resourceId: backgroundServiceWriteAssignment.outputs.resourceId
    appRoleId: backgroundServiceWriteAssignment.outputs.appRoleId
    principalId: backgroundServiceWriteAssignment.outputs.principalId
    principalType: backgroundServiceWriteAssignment.outputs.principalType
    assignedResourceId: backgroundServiceWriteAssignment.outputs.assignedResourceId
  }
  graphDirectoryPermission: {
    resourceId: graphDirectoryPermission.outputs.resourceId
    appRoleId: graphDirectoryPermission.outputs.appRoleId
    principalId: graphDirectoryPermission.outputs.principalId
    principalType: graphDirectoryPermission.outputs.principalType
    assignedResourceId: graphDirectoryPermission.outputs.assignedResourceId
  }
}

@description('User Assignments Information')
output userAssignments object = {
  adminUser: {
    resourceId: adminUserAssignment.outputs.resourceId
    appRoleId: adminUserAssignment.outputs.appRoleId
    principalId: adminUserAssignment.outputs.principalId
    principalType: adminUserAssignment.outputs.principalType
    assignedResourceId: adminUserAssignment.outputs.assignedResourceId
  }
  regularUser: {
    resourceId: regularUserAssignment.outputs.resourceId
    appRoleId: regularUserAssignment.outputs.appRoleId
    principalId: regularUserAssignment.outputs.principalId
    principalType: regularUserAssignment.outputs.principalType
    assignedResourceId: regularUserAssignment.outputs.assignedResourceId
  }
}

@description('Group Assignments Information')
output groupAssignments object = {
  developerGroup: {
    resourceId: developerGroupAssignment.outputs.resourceId
    appRoleId: developerGroupAssignment.outputs.appRoleId
    principalId: developerGroupAssignment.outputs.principalId
    principalType: developerGroupAssignment.outputs.principalType
    assignedResourceId: developerGroupAssignment.outputs.assignedResourceId
  }
  supportGroup: {
    resourceId: supportGroupAssignment.outputs.resourceId
    appRoleId: supportGroupAssignment.outputs.appRoleId
    principalId: supportGroupAssignment.outputs.principalId
    principalType: supportGroupAssignment.outputs.principalType
    assignedResourceId: supportGroupAssignment.outputs.assignedResourceId
  }
}

@description('Batch Assignments Information')
output batchAssignments array = [for (assignment, index) in batchRoleAssignments: {
  name: assignment.name
  description: assignment.description
  resourceId: batchAssignments[index].outputs.resourceId
  appRoleId: batchAssignments[index].outputs.appRoleId
  principalId: batchAssignments[index].outputs.principalId
  principalType: batchAssignments[index].outputs.principalType
  assignedResourceId: batchAssignments[index].outputs.assignedResourceId
}]

@description('Conditional Assignments Information')
output conditionalAssignments object = {
  productionOnly: environment == 'production' ? 'deployed' : 'skipped'
  graphUserPermission: environment != 'development' ? 'deployed' : 'skipped'
}

@description('Test Environment Information')
output testEnvironment object = {
  environment: environment
  applicationName: applicationName
  targetApiServicePrincipalId: targetApiServicePrincipalId
  microsoftGraphServicePrincipalId: microsoftGraphServicePrincipalId
}

@description('Summary of all assignments created')
output assignmentSummary object = {
  servicePrincipalAssignments: 3
  userAssignments: 2
  groupAssignments: 2
  batchAssignments: length(batchRoleAssignments)
  conditionalAssignments: (environment == 'production' ? 1 : 0) + (environment != 'development' ? 1 : 0)
  totalAssignments: 7 + length(batchRoleAssignments) + (environment == 'production' ? 1 : 0) + (environment != 'development' ? 1 : 0)
}

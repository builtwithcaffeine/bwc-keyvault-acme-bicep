// Microsoft Graph App Role Assignment Module
// Creates app role assignments for Azure AD applications and service principals using Microsoft Graph Bicep

metadata name = 'Microsoft Graph App Role Assignment'
metadata description = 'Creates and configures app role assignments for users, groups, or service principals'
metadata owner = 'Platform Team'

// ========== PARAMETERS ==========

@description('Required. The ID of the app role being assigned')
@metadata({
  examples: [
    '00000000-0000-0000-0000-000000000001'
    'df021288-bdef-4463-88db-98f22de89214'
  ]
})
param appRoleId string

@description('Required. The object ID of the principal (user, group, or service principal) receiving the role')
@metadata({
  examples: [
    '12345678-1234-1234-1234-123456789012' // User object ID
    '87654321-4321-4321-4321-210987654321' // Group object ID  
    'abcdef12-3456-7890-abcd-ef1234567890' // Service principal object ID
  ]
})
param principalId string

@description('Required. The object ID of the resource (application or service principal) that defines the app role')
@metadata({
  examples: [
    'fedcba98-7654-3210-fedc-ba9876543210' // Service principal object ID that defines the app role
  ]
})
param resourceId string

@description('Required. The display name of the resource app\'s service principal to which the assignment is made')
@metadata({
  examples: [
    'My API Application'
    'Microsoft Graph'
    'SharePoint Online'
  ]
})
param resourceDisplayName string

@description('Optional. The type of principal receiving the role (for documentation purposes only)')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param principalType string = 'ServicePrincipal'

// ========== RESOURCES ==========

extension microsoftGraphV1

@description('Microsoft Graph App Role Assignment')
resource appRoleAssignment 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  appRoleId: appRoleId
  principalId: principalId
  resourceId: resourceId
  resourceDisplayName: resourceDisplayName
}

// ========== OUTPUTS ==========

@description('The resource ID of the app role assignment')
output resourceId string = appRoleAssignment.id

@description('The app role ID that was assigned')
output appRoleId string = appRoleAssignment.appRoleId

@description('The principal ID that received the role')
output principalId string = appRoleAssignment.principalId

@description('The resource ID that defines the app role')
output assignedResourceId string = appRoleAssignment.resourceId

@description('The principal type')
output principalType string = principalType

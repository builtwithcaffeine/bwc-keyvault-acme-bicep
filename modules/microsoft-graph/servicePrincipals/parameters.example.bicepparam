using 'main.bicep'

// Application reference
param appId = '12345678-1234-1234-1234-123456789012'

// Service principal configuration
param displayName = 'My Sample Service Principal'
param servicePrincipalDescription = 'A sample service principal created using the Microsoft Graph Bicep module'

// Service principal settings
param accountEnabled = true
param appRoleAssignmentRequired = false
param servicePrincipalType = 'Application'

// Metadata
param tags = [
  'sample'
  'bicep'
]

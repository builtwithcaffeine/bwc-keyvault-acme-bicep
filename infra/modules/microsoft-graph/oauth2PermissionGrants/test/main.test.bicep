/*
  Test deployment for Microsoft Graph OAuth2 Permission Grants Module
  
  This file demonstrates comprehensive usage patterns for OAuth2 permission grants
  including organization-wide consent, user-specific consent, Microsoft Graph permissions,
  custom API permissions, and various scope configurations.
  
  Prerequisites:
  - Microsoft Graph Bicep extension v1.0 installed
  - Appropriate Azure AD permissions (Application Administrator or higher)
  - Valid service principal object IDs for client and resource applications
  - Valid user object IDs for user-specific consent scenarios
  
  Usage:
  az deployment group create \
    --resource-group myResourceGroup \
    --template-file main.test.bicep \
    --parameters @test.parameters.json
*/

targetScope = 'resourceGroup'

// ========== PARAMETERS ==========

// Environment and naming parameters
@description('Environment name for deployment naming and tagging')
param environment string = 'test'

@description('Application prefix for resource naming')
param applicationPrefix string = 'oauth2test'

// Client service principal IDs - Replace with actual values
@description('Service principal ID for enterprise application requiring broad permissions')
param enterpriseClientId string = '11111111-1111-1111-1111-111111111111'

@description('Service principal ID for user-specific application')
param userAppClientId string = '22222222-2222-2222-2222-222222222222'

@description('Service principal ID for DevOps/automation application')
param devopsClientId string = '33333333-3333-3333-3333-333333333333'

@description('Service principal ID for reporting application')
param reportingClientId string = '44444444-4444-4444-4444-444444444444'

@description('Service principal ID for custom API client')
param customApiClientId string = '55555555-5555-5555-5555-555555555555'

// Resource service principal IDs
@description('Microsoft Graph service principal ID (constant)')
param microsoftGraphId string = '00000003-0000-0000-c000-000000000000'

@description('SharePoint Online service principal ID (constant)')
param sharepointOnlineId string = '00000003-0000-0ff1-ce00-000000000000'

@description('Exchange Online service principal ID (constant)')
param exchangeOnlineId string = '00000002-0000-0ff1-ce00-000000000000'

@description('Custom API service principal ID')
param customApiResourceId string = '77777777-7777-7777-7777-777777777777'

// User IDs for user-specific grants
@description('Target user ID for user-specific permission grants')
param targetUserId string = '88888888-8888-8888-8888-888888888888'

@description('Administrator user ID for admin-specific grants')
param adminUserId string = '99999999-9999-9999-9999-999999999999'

// ========== VARIABLES ==========

var deploymentName = '${applicationPrefix}-${environment}'

// Common permission scopes for different scenarios
var enterpriseScopes = 'User.Read Directory.Read.All Group.Read.All'
var reportingScopes = 'User.ReadBasic.All Directory.Read.All Group.Read.All'
var devopsScopes = 'Application.ReadWrite.All Directory.ReadWrite.All Group.ReadWrite.All'
var userAppScopes = 'User.Read Calendars.Read Mail.Read'
var customApiScopes = 'api://customer-management/Customer.Read api://customer-management/Customer.Write'

// ========== SCENARIO 1: MICROSOFT GRAPH PERMISSIONS ==========

// Scenario 1.1: Enterprise Application with Comprehensive Graph Permissions
module enterpriseGraphPermissions '../main.bicep' = {
  name: '${deploymentName}-enterprise-graph'
  params: {
    clientId: enterpriseClientId
    consentType: 'AllPrincipals'
    resourceId: microsoftGraphId
    scope: enterpriseScopes
  }
}

// Scenario 1.2: Reporting Application with Read-Only Permissions
module reportingGraphPermissions '../main.bicep' = {
  name: '${deploymentName}-reporting-graph'
  params: {
    clientId: reportingClientId
    consentType: 'AllPrincipals'
    resourceId: microsoftGraphId
    scope: reportingScopes
  }
}

// Scenario 1.3: DevOps Application with Administrative Permissions
module devopsGraphPermissions '../main.bicep' = {
  name: '${deploymentName}-devops-graph'
  params: {
    clientId: devopsClientId
    consentType: 'AllPrincipals'
    resourceId: microsoftGraphId
    scope: devopsScopes
  }
}

// ========== SCENARIO 2: USER-SPECIFIC PERMISSIONS ==========

// Scenario 2.1: User-Specific Application Access
module userSpecificPermissions '../main.bicep' = {
  name: '${deploymentName}-user-specific'
  params: {
    clientId: userAppClientId
    consentType: 'Principal'
    principalId: targetUserId
    resourceId: microsoftGraphId
    scope: userAppScopes
  }
}

// Scenario 2.2: Administrator-Only Permissions
module adminOnlyPermissions '../main.bicep' = {
  name: '${deploymentName}-admin-only'
  params: {
    clientId: enterpriseClientId
    consentType: 'Principal'
    principalId: adminUserId
    resourceId: microsoftGraphId
    scope: 'Directory.ReadWrite.All Application.ReadWrite.All'
  }
}

// ========== SCENARIO 3: OFFICE 365 SERVICE PERMISSIONS ==========

// Scenario 3.1: SharePoint Online Permissions
module sharepointPermissions '../main.bicep' = {
  name: '${deploymentName}-sharepoint'
  params: {
    clientId: enterpriseClientId
    consentType: 'AllPrincipals'
    resourceId: sharepointOnlineId
    scope: 'Sites.Read.All Files.Read.All'
  }
}

// Scenario 3.2: Exchange Online Permissions
module exchangePermissions '../main.bicep' = {
  name: '${deploymentName}-exchange'
  params: {
    clientId: enterpriseClientId
    consentType: 'AllPrincipals'
    resourceId: exchangeOnlineId
    scope: 'Mail.Read Calendars.Read'
  }
}

// ========== SCENARIO 4: CUSTOM API PERMISSIONS ==========

// Scenario 4.1: Custom API Access for All Users
module customApiPermissions '../main.bicep' = {
  name: '${deploymentName}-custom-api'
  params: {
    clientId: customApiClientId
    consentType: 'AllPrincipals'
    resourceId: customApiResourceId
    scope: customApiScopes
  }
}

// Scenario 4.2: Custom API with Limited User Access
module customApiUserPermissions '../main.bicep' = {
  name: '${deploymentName}-custom-api-user'
  params: {
    clientId: customApiClientId
    consentType: 'Principal'
    principalId: targetUserId
    resourceId: customApiResourceId
    scope: 'api://customer-management/Customer.Read'
  }
}

// ========== SCENARIO 5: MINIMAL AND EDGE CASES ==========

// Scenario 5.1: Basic OpenID Connect Permissions
module basicOidcPermissions '../main.bicep' = {
  name: '${deploymentName}-basic-oidc'
  params: {
    clientId: userAppClientId
    consentType: 'AllPrincipals'
    resourceId: microsoftGraphId
    scope: 'openid profile email'
  }
}

// Scenario 5.2: Empty Scope (Default Permissions)
module defaultPermissions '../main.bicep' = {
  name: '${deploymentName}-default'
  params: {
    clientId: userAppClientId
    consentType: 'AllPrincipals'
    resourceId: microsoftGraphId
    scope: ''
  }
}

// ========== SCENARIO 6: BATCH PERMISSIONS ==========

// Define multiple permission grants for batch processing
var batchPermissionGrants = [
  {
    name: 'graph-readonly'
    clientId: reportingClientId
    resourceId: microsoftGraphId
    scope: 'User.Read Directory.Read.All'
    consentType: 'AllPrincipals'
  }
  {
    name: 'sharepoint-readonly'
    clientId: reportingClientId
    resourceId: sharepointOnlineId
    scope: 'Sites.Read.All'
    consentType: 'AllPrincipals'
  }
  {
    name: 'exchange-readonly'
    clientId: reportingClientId
    resourceId: exchangeOnlineId
    scope: 'Mail.Read'
    consentType: 'AllPrincipals'
  }
]

// Create batch permission grants
module batchPermissions '../main.bicep' = [for (grant, index) in batchPermissionGrants: {
  name: '${deploymentName}-batch-${grant.name}-${index}'
  params: {
    clientId: grant.clientId
    consentType: grant.consentType
    resourceId: grant.resourceId
    scope: grant.scope
  }
}]

// ========== SCENARIO 7: CONDITIONAL PERMISSIONS ==========

// Environment-specific permission grants
module conditionalDevopsPermissions '../main.bicep' = if (environment == 'production') {
  name: '${deploymentName}-conditional-devops'
  params: {
    clientId: devopsClientId
    consentType: 'AllPrincipals'
    resourceId: microsoftGraphId
    scope: environment == 'production' ? 'Directory.Read.All' : 'Directory.ReadWrite.All'
  }
}

// ========== OUTPUTS ==========

@description('Microsoft Graph Permissions Information')
output microsoftGraphPermissions object = {
  enterprise: {
    resourceId: enterpriseGraphPermissions.outputs.resourceId
    grantId: enterpriseGraphPermissions.outputs.oauth2PermissionGrantId
    clientId: enterpriseGraphPermissions.outputs.clientId
    consentType: enterpriseGraphPermissions.outputs.consentType
    scope: enterpriseGraphPermissions.outputs.scope
  }
  reporting: {
    resourceId: reportingGraphPermissions.outputs.resourceId
    grantId: reportingGraphPermissions.outputs.oauth2PermissionGrantId
    clientId: reportingGraphPermissions.outputs.clientId
    consentType: reportingGraphPermissions.outputs.consentType
    scope: reportingGraphPermissions.outputs.scope
  }
  devops: {
    resourceId: devopsGraphPermissions.outputs.resourceId
    grantId: devopsGraphPermissions.outputs.oauth2PermissionGrantId
    clientId: devopsGraphPermissions.outputs.clientId
    consentType: devopsGraphPermissions.outputs.consentType
    scope: devopsGraphPermissions.outputs.scope
  }
}

@description('User-Specific Permissions Information')
output userSpecificPermissions object = {
  userApp: {
    resourceId: userSpecificPermissions.outputs.resourceId
    grantId: userSpecificPermissions.outputs.oauth2PermissionGrantId
    clientId: userSpecificPermissions.outputs.clientId
    consentType: userSpecificPermissions.outputs.consentType
    principalId: userSpecificPermissions.outputs.principalId
    scope: userSpecificPermissions.outputs.scope
  }
  adminOnly: {
    resourceId: adminOnlyPermissions.outputs.resourceId
    grantId: adminOnlyPermissions.outputs.oauth2PermissionGrantId
    clientId: adminOnlyPermissions.outputs.clientId
    consentType: adminOnlyPermissions.outputs.consentType
    principalId: adminOnlyPermissions.outputs.principalId
    scope: adminOnlyPermissions.outputs.scope
  }
}

@description('Office 365 Service Permissions Information')
output office365Permissions object = {
  sharepoint: {
    resourceId: sharepointPermissions.outputs.resourceId
    grantId: sharepointPermissions.outputs.oauth2PermissionGrantId
    resourceServicePrincipalId: sharepointPermissions.outputs.resourceServicePrincipalId
    scope: sharepointPermissions.outputs.scope
  }
  exchange: {
    resourceId: exchangePermissions.outputs.resourceId
    grantId: exchangePermissions.outputs.oauth2PermissionGrantId
    resourceServicePrincipalId: exchangePermissions.outputs.resourceServicePrincipalId
    scope: exchangePermissions.outputs.scope
  }
}

@description('Custom API Permissions Information')
output customApiPermissions object = {
  allUsers: {
    resourceId: customApiPermissions.outputs.resourceId
    grantId: customApiPermissions.outputs.oauth2PermissionGrantId
    consentType: customApiPermissions.outputs.consentType
    scope: customApiPermissions.outputs.scope
  }
  specificUser: {
    resourceId: customApiUserPermissions.outputs.resourceId
    grantId: customApiUserPermissions.outputs.oauth2PermissionGrantId
    consentType: customApiUserPermissions.outputs.consentType
    principalId: customApiUserPermissions.outputs.principalId
    scope: customApiUserPermissions.outputs.scope
  }
}

@description('Basic Permission Scenarios Information')
output basicPermissions object = {
  oidc: {
    resourceId: basicOidcPermissions.outputs.resourceId
    grantId: basicOidcPermissions.outputs.oauth2PermissionGrantId
    scope: basicOidcPermissions.outputs.scope
  }
  default: {
    resourceId: defaultPermissions.outputs.resourceId
    grantId: defaultPermissions.outputs.oauth2PermissionGrantId
    scope: defaultPermissions.outputs.scope
  }
}

@description('Batch Permissions Information')
output batchPermissions array = [for (grant, index) in batchPermissionGrants: {
  name: grant.name
  resourceId: batchPermissions[index].outputs.resourceId
  grantId: batchPermissions[index].outputs.oauth2PermissionGrantId
  clientId: batchPermissions[index].outputs.clientId
  consentType: batchPermissions[index].outputs.consentType
  resourceServicePrincipalId: batchPermissions[index].outputs.resourceServicePrincipalId
  scope: batchPermissions[index].outputs.scope
}]

@description('Conditional Permissions Information')
output conditionalPermissions object = {
  devopsProductionOnly: environment == 'production' ? 'deployed' : 'skipped'
}

@description('Test Environment Summary')
output testSummary object = {
  environment: environment
  deploymentName: deploymentName
  microsoftGraphId: microsoftGraphId
  sharepointOnlineId: sharepointOnlineId
  exchangeOnlineId: exchangeOnlineId
  customApiResourceId: customApiResourceId
  totalPermissionGrants: 10 + length(batchPermissionGrants) + (environment == 'production' ? 1 : 0)
}

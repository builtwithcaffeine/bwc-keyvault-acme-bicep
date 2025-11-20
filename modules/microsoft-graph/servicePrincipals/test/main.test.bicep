// Test deployment for Microsoft Graph Service Principals Module
// This file demonstrates how to use the module in different scenarios

targetScope = 'resourceGroup'

// ========== PARAMETERS ==========

@description('Environment name (dev, test, prod)')
param environmentName string = 'dev'

@description('Application prefix')
param appPrefix string = 'contoso'

@description('Existing application ID for basic service principal')
param basicAppId string = '12345678-1234-1234-1234-123456789012'

@description('Existing application ID for SSO service principal')
param ssoAppId string = '87654321-4321-4321-4321-210987654321'

@description('Existing application ID for restricted service principal')
param restrictedAppId string = '11111111-2222-3333-4444-555555555555'

// ========== VARIABLES ==========

var commonTags = [
  'managed-by-bicep'
  environmentName
]

var commonOwners = [
  // Add owner object IDs here if needed
]

// ========== MODULE DEPLOYMENTS ==========

// Example 1: Basic Service Principal
module basicServicePrincipal '../main.bicep' = {
  name: 'basic-sp-deployment'
  params: {
    appId: basicAppId
    displayName: '${appPrefix}-basic-${environmentName}'
    servicePrincipalDescription: 'Basic service principal for ${environmentName} environment'
    accountEnabled: true
    servicePrincipalType: 'Application'
    tags: union(commonTags, ['basic'])
    ownerIds: commonOwners
  }
}

// Example 2: SSO Service Principal
module ssoServicePrincipal '../main.bicep' = {
  name: 'sso-sp-deployment'
  params: {
    appId: ssoAppId
    displayName: '${appPrefix}-sso-${environmentName}'
    servicePrincipalDescription: 'SSO-enabled service principal for ${environmentName}'
    accountEnabled: true
    preferredSingleSignOnMode: 'saml'
    loginUrl: 'https://${appPrefix}-${environmentName}.azurewebsites.net/login'
    logoutUrl: 'https://${appPrefix}-${environmentName}.azurewebsites.net/logout'
    replyUrls: [
      'https://${appPrefix}-${environmentName}.azurewebsites.net/callback'
    ]
    notificationEmailAddresses: [
      'admin@${appPrefix}.com'
    ]
    tags: union(commonTags, ['sso', 'saml'])
    ownerIds: commonOwners
  }
}

// Example 3: Restricted Service Principal (Role Assignment Required)
module restrictedServicePrincipal '../main.bicep' = {
  name: 'restricted-sp-deployment'
  params: {
    appId: restrictedAppId
    displayName: '${appPrefix}-restricted-${environmentName}'
    servicePrincipalDescription: 'Restricted service principal requiring role assignments for ${environmentName}'
    accountEnabled: true
    appRoleAssignmentRequired: true
    servicePrincipalType: 'Application'
    notificationEmailAddresses: [
      'security@${appPrefix}.com'
      'admin@${appPrefix}.com'
    ]
    tags: union(commonTags, ['restricted', 'high-security'])
    notes: 'This service principal requires explicit role assignments for access'
    ownerIds: commonOwners
  }
}

// ========== OUTPUTS ==========

@description('Basic Service Principal Information')
output basicServicePrincipal object = {
  resourceId: basicServicePrincipal.outputs.resourceId
  servicePrincipalId: basicServicePrincipal.outputs.servicePrincipalId
  appId: basicServicePrincipal.outputs.appId
  displayName: basicServicePrincipal.outputs.displayName
}

@description('SSO Service Principal Information')
output ssoServicePrincipal object = {
  resourceId: ssoServicePrincipal.outputs.resourceId
  servicePrincipalId: ssoServicePrincipal.outputs.servicePrincipalId
  appId: ssoServicePrincipal.outputs.appId
  displayName: ssoServicePrincipal.outputs.displayName
}

@description('Restricted Service Principal Information')
output restrictedServicePrincipal object = {
  resourceId: restrictedServicePrincipal.outputs.resourceId
  servicePrincipalId: restrictedServicePrincipal.outputs.servicePrincipalId
  appId: restrictedServicePrincipal.outputs.appId
  displayName: restrictedServicePrincipal.outputs.displayName
  appRoleAssignmentRequired: restrictedServicePrincipal.outputs.appRoleAssignmentRequired
}

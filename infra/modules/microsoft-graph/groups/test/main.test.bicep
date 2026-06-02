// Test deployment for Microsoft Graph Groups Module
// This file demonstrates common supported scenarios for validation

targetScope = 'resourceGroup'

// ========== PARAMETERS ==========

@description('Environment name (dev, test, prod)')
param environmentName string = 'dev'

@description('Organization name prefix for group naming')
param organizationPrefix string = 'contoso'

@description('Owner user object IDs for group management')
param ownerUserIds array = []

@description('Test user object IDs for group membership')
param testUserIds array = []

// ========== VARIABLES ==========

var environmentSuffix = toUpper(environmentName)
var baseName = '${organizationPrefix}-${environmentName}'

// ========== TEST SCENARIO 1: Basic Security Group ==========

@description('Basic security group for access control')
module basicSecurityGroup '../main.bicep' = {
  name: 'test-basic-security-group'
  params: {
    displayName: '${organizationPrefix} IT Team - ${environmentSuffix}'
    groupName: '${baseName}-it'
    mailNickname: '${organizationPrefix}it${environmentName}'
    groupDescription: 'Basic security group for IT team access control in ${environmentName} environment'
    securityEnabled: true
    mailEnabled: false
    groupTypes: []
    classification: environmentName == 'prod' ? 'High' : 'Medium'

    ownerIds: ownerUserIds
    memberIds: testUserIds
  }
}

// ========== TEST SCENARIO 2: Microsoft 365 Group ==========

@description('Microsoft 365 collaboration group')
module collaborationGroup '../main.bicep' = {
  name: 'test-collaboration-group'
  params: {
    displayName: '${organizationPrefix} Collaboration - ${environmentSuffix}'
    groupName: '${baseName}-collab'
    mailNickname: '${organizationPrefix}collab${environmentName}'
    groupDescription: 'Microsoft 365 collaboration group for ${environmentName} environment'
    mailEnabled: true
    securityEnabled: true
    groupTypes: [
      'Unified'
    ]
    visibility: 'Private'
    preferredLanguage: 'en-US'
    preferredDataLocation: 'EUR'
    theme: 'Blue'
    ownerIds: ownerUserIds
    memberIds: testUserIds
  }
}

// ========== TEST SCENARIO 3: Dynamic Security Group ==========

@description('Dynamic security group based on user attributes')
module dynamicSecurityGroup '../main.bicep' = {
  name: 'test-dynamic-security-group'
  params: {
    displayName: '${organizationPrefix} Dynamic Users - ${environmentSuffix}'
    groupName: '${baseName}-dynamic'
    mailNickname: '${organizationPrefix}dynamic${environmentName}'
    groupDescription: 'Dynamic security group for enabled ${environmentName} users'
    securityEnabled: true
    mailEnabled: false
    membershipRule: '(user.accountEnabled -eq true)'
    membershipRuleProcessingState: 'On'
    ownerIds: ownerUserIds
  }
}

// ========== OUTPUTS ==========

@description('Basic Security Group Information')
output basicSecurityGroup object = {
  resourceId: basicSecurityGroup.outputs.resourceId
  groupId: basicSecurityGroup.outputs.groupId
  displayName: basicSecurityGroup.outputs.displayName
  mailNickname: basicSecurityGroup.outputs.mailNickname
  visibility: basicSecurityGroup.outputs.visibility
  securityEnabled: basicSecurityGroup.outputs.securityEnabled
}

@description('Microsoft 365 Collaboration Group Information')
output collaborationGroup object = {
  resourceId: collaborationGroup.outputs.resourceId
  groupId: collaborationGroup.outputs.groupId
  displayName: collaborationGroup.outputs.displayName
  mailNickname: collaborationGroup.outputs.mailNickname
  visibility: collaborationGroup.outputs.visibility
  groupTypes: collaborationGroup.outputs.groupTypes
}

@description('Dynamic Security Group Information')
output dynamicSecurityGroup object = {
  resourceId: dynamicSecurityGroup.outputs.resourceId
  groupId: dynamicSecurityGroup.outputs.groupId
  displayName: dynamicSecurityGroup.outputs.displayName
  mailNickname: dynamicSecurityGroup.outputs.mailNickname
  securityEnabled: dynamicSecurityGroup.outputs.securityEnabled
  isAssignableToRole: dynamicSecurityGroup.outputs.isAssignableToRole
}

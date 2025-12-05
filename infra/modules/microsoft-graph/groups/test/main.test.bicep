// Test deployment for Microsoft Graph Groups Module
// This file demonstrates basic group scenarios for testing

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

// ========== TEST SCENARIO 1: Basic Security Group ==========

@description('Basic security group for access control')
module basicSecurityGroup '../main.bicep' = {
  name: 'test-basic-security-group'
  params: {
    displayName: '${organizationPrefix} IT Team - ${environmentSuffix}'
    groupName: '${organizationPrefix}itteam${environmentName}'
    mailNickname: '${organizationPrefix}itteam${environmentName}'
    groupDescription: 'Basic security group for IT team access control in ${environmentName} environment'
    securityEnabled: true
    mailEnabled: false
    visibility: 'Private'
    classification: environmentName == 'prod' ? 'High' : 'Medium'
    
    ownerIds: ownerUserIds
    memberIds: testUserIds
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

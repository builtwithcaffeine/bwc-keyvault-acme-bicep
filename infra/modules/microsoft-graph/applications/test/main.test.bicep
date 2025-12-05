// Comprehensive test deployment for Microsoft Graph Application Module
// This file demonstrates advanced scenarios and edge cases

targetScope = 'resourceGroup'

// ========== PARAMETERS ==========

@description('Environment name for testing')
param environmentName string = 'test'

@description('Organization name for testing')
param organizationName string = 'contoso'

@description('Application name prefix')
param appNamePrefix string = 'testapp'

@description('Test owner user ID (optional)')
param testOwnerId string = ''

// ========== VARIABLES ==========

var commonTags = [
  'test-environment'
  'managed-by-bicep'
  'comprehensive-test'
  environmentName
]

var testSuffix = '-${environmentName}-${uniqueString(resourceGroup().id)}'

// ========== ADVANCED TEST SCENARIOS ==========

// Scenario 1: Enterprise Web Application with Full Configuration
module enterpriseWebApp '../main.bicep' = {
  name: 'enterprise-web-app-test'
  params: {
    displayName: '${appNamePrefix}-enterprise-web${testSuffix}'
    appName: '${appNamePrefix}-enterprise-web${testSuffix}'
    appDescription: 'Enterprise web application with comprehensive configuration for testing'
    signInAudience: 'AzureADMyOrg'
    
    // Web configuration
    webRedirectUris: [
      'https://${appNamePrefix}-web-${environmentName}.azurewebsites.net/signin-oidc'
      'https://${appNamePrefix}-web-${environmentName}.azurewebsites.net/auth/callback'
      'https://localhost:5001/signin-oidc'
    ]
    homePageUrl: 'https://${appNamePrefix}-web-${environmentName}.azurewebsites.net'
    logoutUrl: 'https://${appNamePrefix}-web-${environmentName}.azurewebsites.net/signout'
    
    // Token configuration
    enableIdTokenIssuance: true
    enableAccessTokenIssuance: false
    requestedAccessTokenVersion: 2
    groupMembershipClaims: 'SecurityGroup'
    
    // API permissions with multiple resources
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '37f7f235-527c-4136-accd-4a02d197296e' // User.ReadBasic.All
            type: 'Scope'
          }
          {
            id: '64a6cdd6-aab1-4aab-94b8-3cc8405e90d0' // Directory.Read.All (Application permission)
            type: 'Role'
          }
        ]
      }
    ]
    
    // Optional claims
    optionalClaims: {
      accessToken: [
        {
          name: 'groups'
          essential: false
        }
        {
          name: 'preferred_username'
          essential: false
        }
      ]
      idToken: [
        {
          name: 'groups'
          essential: false
        }
        {
          name: 'email'
          essential: false
        }
      ]
    }
    
    // Application information
    applicationInfo: {
      marketingUrl: 'https://${organizationName}.com/products/${appNamePrefix}'
      privacyStatementUrl: 'https://${organizationName}.com/privacy'
      supportUrl: 'https://support.${organizationName}.com/${appNamePrefix}'
      termsOfServiceUrl: 'https://${organizationName}.com/terms'
    }
    
    // Metadata
    tags: commonTags
    notes: 'Comprehensive test application with enterprise features'
    serviceManagementReference: 'TEST-ENT-001'
    
    // Owners (if provided)
    ownerIds: !empty(testOwnerId) ? [testOwnerId] : []
  }
}

// Scenario 2: React SPA with Modern Configuration
module reactSpaApp '../main.bicep' = {
  name: 'react-spa-test'
  params: {
    displayName: '${appNamePrefix}-react-spa${testSuffix}'
    appName: '${appNamePrefix}-react-spa${testSuffix}'
    appDescription: 'React SPA application for modern web development'
    signInAudience: 'AzureADMultipleOrgs'
    
    // SPA configuration
    spaRedirectUris: [
      'https://${appNamePrefix}-spa-${environmentName}.azurewebsites.net/auth/callback'
      'https://${appNamePrefix}-spa-${environmentName}.azurewebsites.net/silent-renew'
      'http://localhost:3000/auth/callback'
      'http://localhost:3000/silent-renew'
    ]
    
    // Token configuration optimized for SPA
    requestedAccessTokenVersion: 2
    
    // API permissions for SPA scenarios
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '37f7f235-527c-4136-accd-4a02d197296e' // User.ReadBasic.All
            type: 'Scope'
          }
          {
            id: '7427e0e9-2fba-42fe-b0c0-848c9e6a8182' // offline_access
            type: 'Scope'
          }
        ]
      }
    ]
    
    tags: ['spa', 'react', 'frontend', 'test']
    notes: 'Modern React SPA with PKCE authentication flow'
  }
}

// Scenario 3: Mobile Application (Public Client)
module mobileApp '../main.bicep' = {
  name: 'mobile-app-test'
  params: {
    displayName: '${appNamePrefix}-mobile${testSuffix}'
    appName: '${appNamePrefix}-mobile${testSuffix}'
    appDescription: 'Cross-platform mobile application (iOS/Android)'
    signInAudience: 'AzureADMyOrg'
    
    // Public client configuration
    isFallbackPublicClient: true
    publicClientRedirectUris: [
      'msauth.com.${organizationName}.${appNamePrefix}://auth' // iOS
      'msauth://com.${organizationName}.${appNamePrefix}/${uniqueString(resourceGroup().id)}' // Android
      'http://localhost:3000' // Development
    ]
    
    // Device authentication support
    isDeviceOnlyAuthSupported: true
    
    // Mobile-optimized permissions
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '7427e0e9-2fba-42fe-b0c0-848c9e6a8182' // offline_access
            type: 'Scope'
          }
        ]
      }
    ]
    
    tags: ['mobile', 'ios', 'android', 'public-client', 'test']
    notes: 'Cross-platform mobile application with device authentication'
  }
}

// Scenario 4: API Application with Custom Scopes and App Roles
module apiApp '../main.bicep' = {
  name: 'api-app-test'
  params: {
    displayName: '${appNamePrefix}-api${testSuffix}'
    appName: '${appNamePrefix}-api${testSuffix}'
    appDescription: 'Web API with custom scopes and application roles'
    signInAudience: 'AzureADMyOrg'
    
    // API identifier
    identifierUris: ['api://${appNamePrefix}-api${testSuffix}']
    
    // OAuth2 permission scopes
    oauth2PermissionScopes: [
      {
        id: guid('scope1', uniqueString(resourceGroup().id))
        adminConsentDescription: 'Allows the application to read user profiles in the test environment'
        adminConsentDisplayName: 'Read user profiles'
        userConsentDescription: 'Allows the application to read your profile information'
        userConsentDisplayName: 'Read your profile'
        value: 'user.read'
        type: 'User'
        isEnabled: true
      }
      {
        id: guid('scope2', uniqueString(resourceGroup().id))
        adminConsentDescription: 'Allows the application to write user data in the test environment'
        adminConsentDisplayName: 'Write user data'
        userConsentDescription: 'Allows the application to update your information'
        userConsentDisplayName: 'Update your information'
        value: 'user.write'
        type: 'Admin'
        isEnabled: true
      }
      {
        id: guid('scope3', uniqueString(resourceGroup().id))
        adminConsentDescription: 'Allows the application to access test data'
        adminConsentDisplayName: 'Access test data'
        userConsentDescription: 'Allows the application to access test data on your behalf'
        userConsentDisplayName: 'Access test data'
        value: 'test.access'
        type: 'User'
        isEnabled: true
      }
    ]
    
    // Application roles
    appRoles: [
      {
        id: guid('role1', uniqueString(resourceGroup().id))
        displayName: 'Test Administrator'
        description: 'Administrators of the test API with full access rights'
        value: 'Test.Admin'
        allowedMemberTypes: ['User']
        isEnabled: true
      }
      {
        id: guid('role2', uniqueString(resourceGroup().id))
        displayName: 'Test Reader'
        description: 'Read-only access to test API resources'
        value: 'Test.Reader'
        allowedMemberTypes: ['User', 'Application']
        isEnabled: true
      }
      {
        id: guid('role3', uniqueString(resourceGroup().id))
        displayName: 'Test Writer'
        description: 'Write access to test API resources'
        value: 'Test.Writer'
        allowedMemberTypes: ['User']
        isEnabled: true
      }
    ]
    
    // API configuration
    requestedAccessTokenVersion: 2
    acceptMappedClaims: false
    
    tags: ['api', 'backend', 'microservice', 'test']
    notes: 'Test API with comprehensive scope and role definitions'
  }
}

// Scenario 5: Multi-Platform Application
module multiPlatformApp '../main.bicep' = {
  name: 'multi-platform-test'
  params: {
    displayName: '${appNamePrefix}-multiplatform${testSuffix}'
    appName: '${appNamePrefix}-multiplatform${testSuffix}'
    appDescription: 'Multi-platform application supporting web, SPA, and mobile'
    signInAudience: 'AzureADandPersonalMicrosoftAccount'
    
    // Web platform configuration
    webRedirectUris: [
      'https://${appNamePrefix}-multi-${environmentName}.azurewebsites.net/signin-oidc'
    ]
    homePageUrl: 'https://${appNamePrefix}-multi-${environmentName}.azurewebsites.net'
    logoutUrl: 'https://${appNamePrefix}-multi-${environmentName}.azurewebsites.net/signout-oidc'
    enableIdTokenIssuance: true
    
    // SPA platform configuration
    spaRedirectUris: [
      'https://${appNamePrefix}-multi-${environmentName}.azurewebsites.net/spa/callback'
      'http://localhost:3000/auth/callback'
    ]
    
    // Mobile platform configuration
    publicClientRedirectUris: [
      'msauth.com.${organizationName}.multiplatform://auth'
      'http://localhost:8080'
    ]
    isFallbackPublicClient: true
    
    // Token configuration for multi-platform
    requestedAccessTokenVersion: 2
    groupMembershipClaims: 'All'
    
    // Broad permissions for multi-platform scenarios
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
          {
            id: '37f7f235-527c-4136-accd-4a02d197296e' // User.ReadBasic.All
            type: 'Scope'
          }
          {
            id: '7427e0e9-2fba-42fe-b0c0-848c9e6a8182' // offline_access
            type: 'Scope'
          }
        ]
      }
    ]
    
    // Comprehensive application information
    applicationInfo: {
      marketingUrl: 'https://${organizationName}.com/products/multiplatform'
      privacyStatementUrl: 'https://${organizationName}.com/privacy'
      supportUrl: 'https://support.${organizationName}.com/multiplatform'
      termsOfServiceUrl: 'https://${organizationName}.com/terms'
    }
    
    tags: ['multi-platform', 'web', 'spa', 'mobile', 'consumer', 'test']
    notes: 'Comprehensive multi-platform application for consumer and enterprise use'
  }
}

// Scenario 6: Daemon Application (Application Permissions Only)
module daemonApp '../main.bicep' = {
  name: 'daemon-app-test'
  params: {
    displayName: '${appNamePrefix}-daemon${testSuffix}'
    appName: '${appNamePrefix}-daemon${testSuffix}'
    appDescription: 'Daemon application using application permissions'
    signInAudience: 'AzureADMyOrg'
    
    // No redirect URIs for daemon applications
    
    // Application permissions only
    requiredResourceAccess: [
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: '1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9' // Application.ReadWrite.All
            type: 'Role'
          }
          {
            id: '19dbc75e-c2e2-444c-a770-ec69d8559fc7' // Directory.ReadWrite.All
            type: 'Role'
          }
          {
            id: '9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30' // Application.Read.All
            type: 'Role'
          }
        ]
      }
    ]
    
    // Token configuration for daemon
    requestedAccessTokenVersion: 2
    
    tags: ['daemon', 'service', 'background', 'application-permissions', 'test']
    notes: 'Daemon application for automated background processing'
  }
}

// ========== OUTPUTS FOR TESTING ==========

@description('Enterprise Web Application outputs')
output enterpriseWebApp object = {
  applicationId: enterpriseWebApp.outputs.applicationId
  objectId: enterpriseWebApp.outputs.objectId
  displayName: enterpriseWebApp.outputs.displayName
  uniqueName: enterpriseWebApp.outputs.uniqueName
}

@description('React SPA Application outputs')
output reactSpaApp object = {
  applicationId: reactSpaApp.outputs.applicationId
  objectId: reactSpaApp.outputs.objectId
  displayName: reactSpaApp.outputs.displayName
  uniqueName: reactSpaApp.outputs.uniqueName
}

@description('Mobile Application outputs')
output mobileApp object = {
  applicationId: mobileApp.outputs.applicationId
  objectId: mobileApp.outputs.objectId
  displayName: mobileApp.outputs.displayName
  uniqueName: mobileApp.outputs.uniqueName
}

@description('API Application outputs')
output apiApp object = {
  applicationId: apiApp.outputs.applicationId
  objectId: apiApp.outputs.objectId
  displayName: apiApp.outputs.displayName
  uniqueName: apiApp.outputs.uniqueName
  identifierUris: apiApp.outputs.identifierUris
}

@description('Multi-Platform Application outputs')
output multiPlatformApp object = {
  applicationId: multiPlatformApp.outputs.applicationId
  objectId: multiPlatformApp.outputs.objectId
  displayName: multiPlatformApp.outputs.displayName
  uniqueName: multiPlatformApp.outputs.uniqueName
}

@description('Daemon Application outputs')
output daemonApp object = {
  applicationId: daemonApp.outputs.applicationId
  objectId: daemonApp.outputs.objectId
  displayName: daemonApp.outputs.displayName
  uniqueName: daemonApp.outputs.uniqueName
}

@description('Test environment details')
output testEnvironment object = {
  environmentName: environmentName
  organizationName: organizationName
  appNamePrefix: appNamePrefix
  testSuffix: testSuffix
  resourceGroupId: resourceGroup().id
}

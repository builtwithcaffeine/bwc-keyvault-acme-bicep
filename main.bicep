targetScope = 'subscription'
var tenantId = subscription().tenantId

// Imported Values

@description('The Subscription ID')
param subscriptionId string

@description('The Entra Id App ID of the Service Principal')
param spAppId string

@description('The Entra Id App Secret of the Service Principal')
@secure()
param spAuthSecret string

@description('User Id for Key Vault Role Assignment')
param userId string

@description('User Principal ID')
param deployedBy string

@description('Environment Type')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentType string

@description('Location')
param location string

@description('Tags')
param tags object = {
  environmentType: environmentType
  deployBy: deployedBy
  deployedOn: utcNow('yyyy-MM-dd')
}

// Resource Names
param resourceGroupName string = ''
param managedIdentityName string = ''
param keyVaultName string = ''
param logAnalyticsWorkspaceName string = ''
param storageAccountName string = ''
param appServicePlanName string = ''
param appInsightsName string = ''
param functionAppName string = ''

// Virtual Network Parameters
param virtualNetworkCidr string = ''
param virtualNetworkSubnet string = ''
param virtualNetworkName string = ''
var virtualNetworkSubnets = [
  {
    name: 'subnet-kvacme-private-endpoint'
    addressPrefix: virtualNetworkSubnet
  }
]

// ACME Details
var keyvaultAcmePackageUrl = 'https://stacmebotprod.blob.core.windows.net/keyvault-acmebot/v4/latest.zip'
param acmeMailAddress string = ''
param acmeEndPoint string = ''

// Function App Settings
var acmebotAppSettings = {
  MICROSOFT_PROVIDER_AUTHENTICATION_SECRET: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=spAuthSecret)'
  WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=connectionString1)'
  AzureWebJobsStorage: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=connectionString1)'
  WEBSITE_CONTENTSHARE: toLower(functionAppName)
  WEBSITE_RUN_FROM_PACKAGE: keyvaultAcmePackageUrl
  FUNCTIONS_EXTENSION_VERSION: '~4'
  FUNCTIONS_WORKER_RUNTIME: ''

  // Key Vault ACME Configuration
  'Acmebot:Contacts': acmeMailAddress
  'Acmebot:Endpoint': acmeEndPoint
  'Acmebot:VaultBaseUrl': createKeyVault.outputs.uri
  'Acmebot:Environment': environment().name
  'Acmebot:MitigateChainOrder': 'true'
  APPINSIGHTS_INSTRUMENTATIONKEY: createAppInsights.outputs.instrumentationKey
  APPLICATIONINSIGHTS_CONNECTION_STRING: createAppInsights.outputs.connectionString

  // DNS Zone Configuration
  // https://github.com/shibayan/keyvault-acmebot/wiki/DNS-Provider-Configuration

  // Azure DNS Configuration
  // https://github.com/shibayan/keyvault-acmebot/wiki/DNS-Provider-Configuration#azure-dns
  'Acmebot:AzureDns:SubscriptionId': subscriptionId
  'Acmebot:AzurePrivateDns:SubscriptionId': subscriptionId
}
//
// ** Modules **
//

// Module: Create Resource Group
module createResourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'create-resource-group'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// Module: Create Virtual Network
module createVirtualNetwork 'br/public:avm/res/network/virtual-network:0.5.1' = {
  name: 'create-virtual-network'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [
      virtualNetworkCidr
    ]
    subnets: virtualNetworkSubnets
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// Module: Create User Managed Identity
module createUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'create-user-managed-identity'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: managedIdentityName
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// Module: Create Key Vault
module createKeyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  name: 'create-key-vault'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: keyVaultName
    location: location
    sku: 'standard'
    enablePurgeProtection: false
    enableRbacAuthorization: false
    accessPolicies: [
      {
        objectId: createUserManagedIdentity.outputs.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
        tenantId: tenantId
      }
      {
        objectId: userId
        permissions: {
          keys: [
            'get'
            'list'
          ]
          secrets: [
            'get'
            'list'
          ]
          certificates: [
            'get'
            'list'
          ]
        }
        tenantId: tenantId
      }
    ]
    secrets: [
      {
        name: 'spAuthSecret'
        value: spAuthSecret
      }
    ]
    tags: tags
  }
  dependsOn: [
    createUserManagedIdentity
  ]
}

// Module: Create Storage Account
module createStorageAccount 'br/public:avm/res/storage/storage-account:0.15.0' = {
  name: 'create-storage-account'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    secretsExportConfiguration: {
      accessKey1: 'accessKey1'
      accessKey2: 'accessKey2'
      connectionString1: 'connectionString1'
      connectionString2: 'connectionString2'
      keyVaultResourceId: createKeyVault.outputs.resourceId
    }
    tags: tags
  }
  dependsOn: [
    createKeyVault
  ]
}

// Module: Create Log Analytics Workspace
module createLogAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.9.0' = {
  name: 'create-log-analytics-workspace'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    skuName: 'PerGB2018'
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// Module: Create Application Insights
module createAppInsights 'br/public:avm/res/insights/component:0.4.2' = {
  name: 'create-app-insights'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: appInsightsName
    location: location
    workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
    tags: tags
  }
  dependsOn: [
    createLogAnalyticsWorkspace
  ]
}

// Module: Create App Service Plan
module createAppServicePlan 'br/public:avm/res/web/serverfarm:0.4.0' = {
  name: 'create-app-service-plan'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: appServicePlanName
    location: location
    kind: 'windows'
    skuName: 'Y1'
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// Module: Create Function App
module createFunctionApp 'br/public:avm/res/web/site:0.12.0' = {
  name: 'create-function-app'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: functionAppName
    location: location
    kind: 'functionapp'
    clientAffinityEnabled: false
    storageAccountRequired: true
    keyVaultAccessIdentityResourceId: createUserManagedIdentity.outputs.resourceId
    storageAccountResourceId: createStorageAccount.outputs.resourceId
    serverFarmResourceId: createAppServicePlan.outputs.resourceId
    appInsightResourceId: createAppInsights.outputs.resourceId
    managedIdentities: {
      systemAssigned: true // Required for DNS Zone Contributor Role
      userAssignedResourceIds: [
        createUserManagedIdentity.outputs.resourceId
      ]
    }
    basicPublishingCredentialsPolicies: [
      {
        allow: false
        name: 'ftp'
      }
      {
        allow: false
        name: 'scm'
      }
    ]
    appSettingsKeyValuePairs: acmebotAppSettings
    siteConfig: {
      alwaysOn: false
      ftpsState: 'Disabled'
      http20Enabled: true
      netFrameworkVersion: 'v8.0'
      minTlsVersion: '1.3'
    }
    authSettingV2Configuration: {
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            clientId: spAppId
            clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
            openIdIssuer: 'https://sts.windows.net/${tenantId}/v2.0'
          }
        }
      }
      login: {
        tokenStore: {
          enabled: true
        }
      }
      platform: {
        enabled: true
        runtimeVersion: '~1'
      }
      globalValidation: {
        requireAuthentication: true
        redirectToProvider: 'AzureActiveDirectory'
        unauthenticatedClientAction: 'RedirectToLoginPage'
      }
    }
    tags: tags
  }
  dependsOn: [
    createAppServicePlan
    createStorageAccount
    createAppInsights
    createKeyVault
  ]
}

output systemAssignedIdentityId string = createFunctionApp.outputs.systemAssignedMIPrincipalId
output keyVaultName string = createKeyVault.outputs.name

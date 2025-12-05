targetScope = 'subscription'

//
@description('Azure Tenant Id')
var tenantId = subscription().tenantId

@description('Customer name - used for naming resources')
param customerName string

@description('Azure Location')
param location string

@description('Azure Location Short Code')
param locationShortCode string

@description('Environment Type')
@allowed(['dev', 'acc', 'prod'])
param environmentType string

@description('Deployed By')
param deployedBy string

param tags object = {
  environmentType: environmentType
  deployedBy: deployedBy
  deployedDate: utcNow('yyyy-MM-dd')
}

//
// Parameters [Created Resources]

@description('Resource Group Name')
param resourceGroupName string = 'rg-x-${customerName}-kvacme-${environmentType}-${locationShortCode}'

@description('Key Vault Name')
param keyvaultName string = 'kv-${customerName}-kvacme-${environmentType}-${locationShortCode}'

@description('User Managed Identity Name')
param userManagedIdentityName string = 'id-${customerName}-kvacme-${environmentType}-${locationShortCode}'

@description('Log Analytics Workspace Name')
param logAnalyticsWorkspaceName string = 'log-${customerName}-kvacme-${environmentType}-${locationShortCode}'

@description('Storage Account Name')
param storageAccountName string = 'st${customerName}kvacme${environmentType}${locationShortCode}'

@description('Application Insights Name')
param applicationInsightsName string = 'appi-${customerName}-kvacme-${environmentType}-${locationShortCode}'

@description('App Service Plan Name')
param appServicePlanName string = 'asp-${customerName}-kvacme-${environmentType}-${locationShortCode}'

@description('Function App Name')
param functionAppName string = 'func-${customerName}-kvacme-${environmentType}-${locationShortCode}'

@description('App Registration Name')
param appRegistrationName string = 'sp-kvacme-authentication-${environmentType}'

//
// Parameters [Existing Resources]
// Imported from parameters file or passed in at deployment time

@description('Shared Hub - Resource Group Name')
param sharedResourceGroupName string

// Azure Virtual Network

@description('Enable Create Private Dns Zones')
param enableCreatePrivateDnsZones bool

@description('Enable Create Virtual Network Module')
param enableCreateVirtualNetwork bool

@description('Virtual Network Name')
param virtualNetworkName string

@description('Virtual Network Address Prefix')
param virtualNetworkAddressPrefix string

@description('Virtual Network Subnet - Shared Resources')
param virtualNetworkSubnetShared string

@description('Virtual Network Subnet - App Service')
param virtualNetworkSubnetAppService string

//

@description('Existing Virtual Network Resource Group Name')
param existingVirtualNetworkResourceGroup string

@description('Existing Virtual Network Name')
param existingVirtualNetworkName string

@description('Existing Virtual Network Subnet - Shared Resources')
param existingVirtualNetworkSubnetSharedName string

@description('Existing Virtual Network Subnet - App Service')
param existingVirtualNetworkSubnetAppServiceName string

// App Service Plan

@description('App Service Kind')
@allowed(['windows'])
param appServiceKind string = 'windows'

@description('App Service Sku Name')
@allowed(['B1', 'B2'])
param appServiceSkuName string = 'B1'

// Azure Key Vault
@description('Create Key Vault Resource')
param createWithKeyVault bool

@description('Existing Key Vault - Resource Group Name')
param existingKeyVaultResourceGroup string

@description('Existing Key Vault - Resource Name')
param existingKeyVaultName string

@description('Key Vault Access Policy - User Managed Identity')
var kvAccessPolicies = [
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
]

// Key Vault ACME Values
@description('Key Vault ACME Package URL')
param acmeKvACMEPackage string

@description('Azure Subscription Id - Public Dns Zones')
param acmeAzurePublicDnsSubscriptionId string

@description('Azure Subscription Id - Private Dns Zones')
param acmeAzurePrivateDnsSubscriptionId string

@description('Enable Public Dns Role Assignment Module')
param enablePublicDnsRoleAssignment bool

@description('Azure Public Dns Resource Group')
param azurePublicDnsResourceGroup string

@description('Azure Public Dns Resource Id')
param azurePublicDnsZones array

@description('Enable Private Dns Role Assignment Module')
param enablePrivateDnsRoleAssignment bool

@description('Azure Private Dns Resource Group')
param azurePrivateDnsResourceGroup string

@description('Azure Private Dns Resource Id')
param azurePrivateDnsZones array

@allowed([
  'https://acme-v02.api.letsencrypt.org/directory'
  'https://api.buypass.com/acme/directory'
  'https://acme.zerossl.com/v2/DV90/'
  'https://dv.acme-v02.api.pki.goog/directory'
  'https://acme.ssl.com/sslcom-dv-rsa'
  'https://acme.ssl.com/sslcom-dv-ecc'
])
@description('Lets Encrypt Public End point')
param acmeEndpoint string

@description('Azure Environment')
param acmeEnvironment string

@description('Key Vault ACME - Key Vault Reference')
param acmeKeyVaultUrlBase string

@description('Key Vault ACME - Email Contact(s)')
@secure()
param acmeContacts string

//
@description('Key Vault Name Variable')
var selectedKeyVaultName = createWithKeyVault ? keyvaultName : existingKeyVaultName

@description('Private Dns Zones Array Variable')
var privateDnsZonesArray = [
  'privatelink.vaultcore.azure.net' // [0]
  'privatelink.blob.${environment().suffixes.storage}' // [1]
  'privatelink.file.${environment().suffixes.storage}' // [2]
  'privatelink.table.${environment().suffixes.storage}' // [3]
  'privatelink.queue.${environment().suffixes.storage}' // [4]
  'privatelink.azurewebsites.net' // [5]
  'scm.privatelink.azurewebsites.net' // [6]
]

//
// Azure Resource - [Existing]
resource sharedVirtualNetwork 'Microsoft.Network/virtualNetworks@2025-01-01' existing = if (!enableCreateVirtualNetwork) {
  scope: resourceGroup(existingVirtualNetworkResourceGroup)
  name: existingVirtualNetworkName
}

resource existingVirtualNetworkSubnetShared 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' existing = if (!enableCreateVirtualNetwork) {
  parent: sharedVirtualNetwork
  name: existingVirtualNetworkSubnetSharedName
}

resource existingVirtualNetworkSubnetAppService 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' existing = if (!enableCreateVirtualNetwork) {
  parent: sharedVirtualNetwork
  name: existingVirtualNetworkSubnetAppServiceName
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2025-05-01' existing = if (!createWithKeyVault) {
  scope: resourceGroup(existingKeyVaultResourceGroup)
  name: existingKeyVaultName
}

// Private End Point - Key Vault
resource privateDnsZoneKeyVault 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[0]
}

// Private End Point - Storage Account (Blob)
resource privateDnsZoneStorageBlob 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[1]
}

// Private End Point - Storage Account (Table)
resource privateDnsZoneStorageTable 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[2]
}

// Private End Point - Storage Account (File)
resource privateDnsZoneStorageFile 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[3]
}

// Private End Point - Storage Account (Queue)
resource privateDnsZoneStorageQueue 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[4]
}

// Private End Point - Web Site
resource privateDnsZoneAzureSites 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[5]
}

// Private End Point - Web Site SCM
resource privateDnsZoneAzureSitesScm 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[6]
}

//
// Azure Resource Modules - [Create]
//

// Create Resource Group
module createResourceGroup 'br/public:avm/res/resources/resource-group:0.4.2' = {
  name: 'create-resource-group'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}



module createVirtualNetwork 'br/public:avm/res/network/virtual-network:0.7.1' = if (enableCreateVirtualNetwork) {
  name: 'create-virtual-network'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
    subnets: [
      {
        name: 'snet-shared-resources'
        addressPrefix: virtualNetworkSubnetShared
      }
      {
        name: 'snet-kvacme-appservice'
        addressPrefix: virtualNetworkSubnetAppService
        delegation: 'Microsoft.Web/serverFarms'
      }
    ]
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createPrivateDnsZones 'br/public:avm/res/network/private-dns-zone:0.8.0' = [
  for privateDnsZone in privateDnsZonesArray: if (enableCreatePrivateDnsZones) {
    name: 'create-private-dns-zone-${replace(privateDnsZone, '.', '-')}'
    scope: resourceGroup(resourceGroupName)
    params: {
      name: privateDnsZone
      location: 'global'
      virtualNetworkLinks: [
        {
          virtualNetworkResourceId: createVirtualNetwork.outputs.resourceId
        }
      ]
      tags: tags
    }
    dependsOn: [
      createVirtualNetwork
    ]
  }
]

// Create Entra Security Group
module createEntraSecurityGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'create-entra-security-group'
  scope: resourceGroup(resourceGroupName)
  params: {
    displayName: 'Key Vault ACME - Authentication - ${environmentType}'
    groupName: 'sec-keyvault-acme-auth-${environmentType}'
    mailNickname: 'sec-keyvault-acme-auth-${environmentType}'
    groupDescription: 'Key Vault ACME - Security Group'
    ownerIds: []
    memberIds: []
    mailEnabled: false
    securityEnabled: true
    visibility: 'Private'
  }
  dependsOn: [
    createResourceGroup
  ]
}

// Create Application Registration
module createAppRegistration 'modules/microsoft-graph/applications/main.bicep' = {
  name: 'create-entra-app-registration'
  scope: resourceGroup(resourceGroupName)
  params: {
    displayName: 'Key Vault ACME - Authentication - ${environmentType}'
    appName: appRegistrationName
    appDescription: 'App Registration for Key Vault ACME'
    homePageUrl: 'https://${functionAppName}.azurewebsites.net'
    webRedirectUris: [
      'https://${functionAppName}.azurewebsites.net/.auth/login/aad/callback'
    ]
    enableIdTokenIssuance: true
    requiredResourceAccess: [
      // These need manually accepting in the portal once created
      {
        resourceAppId: '00000003-0000-0000-c000-000000000000' // Microsoft Graph
        resourceAccess: [
          {
            id: '64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0' // email
            type: 'Scope'
          }
          {
            id: '37f7f235-527c-4136-accd-4a02d197296e' // openid
            type: 'Scope'
          }
          {
            id: '14dad69e-099b-42c9-810b-d002981feec1' // profile
            type: 'Scope'
          }
          {
            id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d' // User.Read
            type: 'Scope'
          }
        ]
      }
    ]
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createFederatedCredential 'modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'create-entra-federated-credential'
  scope: resourceGroup(resourceGroupName)
  params: {
    applicationId: createAppRegistration.outputs.uniqueName
    name: 'KeyVaultACME-Federated-Credential-${environmentType}'
    issuer: '${environment().authentication.loginEndpoint}${tenantId}/v2.0'
    credentialDescription: 'Federated Identity Credential for Key Vault ACME - ${environmentType}'
    subject: createUserManagedIdentity.outputs.principalId
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
  dependsOn: [
    createAppRegistration
  ]
}

// Create Enterprise Application
module createServicePrincipal 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'create-entra-service-principal'
  scope: resourceGroup(resourceGroupName)
  params: {
    appId: createAppRegistration.outputs.applicationId
    displayName: 'Key Vault ACME - Authentication - ${environmentType}'
    homepage: 'https://${functionAppName}.azurewebsites.net'
    accountEnabled: true
    appRoleAssignmentRequired: true
  }
  dependsOn: [
    createAppRegistration
  ]
}

// Create User Managed Identity
module createUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.2' = {
  name: 'create-user-managed-identity'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: userManagedIdentityName
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// Create Key Vault - if (createWithKeyVault) - $true
module createKeyVault 'br/public:avm/res/key-vault/vault:0.13.3' = if (createWithKeyVault) {
  name: 'create-keyvault'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: keyvaultName
    location: location
    sku: 'standard'
    enablePurgeProtection: false
    enableRbacAuthorization: false
    accessPolicies: kvAccessPolicies
    privateEndpoints: [
      {
        service: 'vault'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[0].outputs.resourceId
                : privateDnsZoneKeyVault.id
            }
          ]
        }
      }
    ]
    tags: tags
  }
  dependsOn: [
    createUserManagedIdentity
  ]
}

// Update Key Vault - if (!createWithKeyVault) - $false
module updateKeyVaultUserManagedIdentity 'br/public:avm/res/key-vault/vault/access-policy:0.1.0' = if (!createWithKeyVault) {
  scope: resourceGroup(existingKeyVaultResourceGroup)
  params: {
    keyVaultName: existingKeyVaultName
    accessPolicies: kvAccessPolicies
  }
  dependsOn: [
    existingKeyVault
  ]
}

module createStorageAccount 'br/public:avm/res/storage/storage-account:0.29.0' = {
  name: 'create-storage-account'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_ZRS'
    tags: tags
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    secretsExportConfiguration: {
      accessKey1Name: 'accessKey1'
      accessKey2Name: 'accessKey2'
      connectionString1Name: 'connectionString1'
      connectionString2Name: 'connectionString2'
      keyVaultResourceId: createKeyVault.outputs.resourceId
    }
    fileServices: {
      shares: [
        {
          name: functionAppName
          shareQuota: 10
        }
      ]
    }
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[1].outputs.resourceId //blob
                : privateDnsZoneStorageBlob.id
            }
          ]
        }
      }
      {
        service: 'file'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[2].outputs.resourceId // file
                : privateDnsZoneStorageFile.id
            }
          ]
        }
      }
      {
        service: 'table'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[3].outputs.resourceId // table
                : privateDnsZoneStorageTable.id
            }
          ]
        }
      }
      {
        service: 'queue'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[4].outputs.resourceId // queue
                : privateDnsZoneStorageQueue.id
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    createKeyVault
    createResourceGroup
  ]
}

module createLogAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.13.0' = {
  name: 'create-log-analytics-workspace'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    dataRetention: 30
    skuName: 'PerGB2018'
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createApplicationInsights 'br/public:avm/res/insights/component:0.7.0' = {
  name: 'create-application-insights'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: applicationInsightsName
    location: location
    workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
    tags: tags
  }
  dependsOn: [
    createLogAnalyticsWorkspace
  ]
}

module createAppServicePlan 'br/public:avm/res/web/serverfarm:0.5.0' = {
  name: 'create-app-service-plan'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: appServicePlanName
    location: location
    kind: appServiceKind
    skuName: appServiceSkuName
    skuCapacity: 1
    tags: tags
  }
  dependsOn: [
    createApplicationInsights
  ]
}

module createFunctionApp 'br/public:avm/res/web/site:0.19.4' = {
  name: 'create-function-app'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: functionAppName
    location: location
    kind: 'functionapp'
    serverFarmResourceId: createAppServicePlan.outputs.resourceId
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    outboundVnetRouting: {
      applicationTraffic: true
      contentShareTraffic: true
    }
    virtualNetworkSubnetResourceId: enableCreateVirtualNetwork
      ? createVirtualNetwork.outputs.subnetResourceIds[1]
      : existingVirtualNetworkSubnetAppService.id
    keyVaultAccessIdentityResourceId: createUserManagedIdentity.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
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
    configs: [
      {
        storageAccountResourceId: createStorageAccount.outputs.resourceId
        name: 'appsettings'
        properties: {
          // Function App Values
          FUNCTIONS_EXTENSION_VERSION: '~4'
          FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'

          // Application Insights
          APPINSIGHTS_INSTRUMENTATIONKEY: createApplicationInsights.outputs.instrumentationKey
          APPLICATIONINSIGHTS_CONNECTION_STRING: createApplicationInsights.outputs.connectionString

          // Storage
          AzureWebJobsStorage: '@Microsoft.KeyVault(VaultName=${selectedKeyVaultName};SecretName=connectionString1)'
          WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(VaultName=${selectedKeyVaultName};SecretName=connectionString1)'
          WEBSITE_CONTENTSHARE: toLower(functionAppName)
          WEBSITE_RUN_FROM_PACKAGE: acmeKvACMEPackage

          // Enterprise App Values
          WEBSITE_AUTH_AAD_ALLOWED_TENANTS: tenantId
          OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID: createUserManagedIdentity.outputs.clientId
          // https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad?tabs=workforce-configuration#use-a-managed-identity-instead-of-a-secret-preview

          // Key Vault ACME Values
          'Acmebot:MitigateChainOrder': 'true'
          'Acmebot:AzureDns:SubscriptionId': acmeAzurePublicDnsSubscriptionId
          'Acmebot:AzurePrivateDns:SubscriptionId': acmeAzurePrivateDnsSubscriptionId
          'Acmebot:Endpoint': acmeEndpoint
          'Acmebot:Environment': acmeEnvironment
          'Acmebot:VaultBaseUrl': acmeKeyVaultUrlBase
          'Acmebot:Contacts': acmeContacts
        }
      }
      {
        name: 'web'
        properties: {
          cors: {
            allowedOrigins: [
              'https://portal.azure.com'
            ]
            supportCredentials: false
          }
        }
      }
      {
        name: 'authsettingsV2'
        properties: {
          identityProviders: {
            azureActiveDirectory: {
              enabled: true
              registration: {
                clientId: createAppRegistration.outputs.applicationId
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
      }
    ]
    siteConfig: {
      http20Enabled: true
      alwaysOn: true
      minTlsVersion: '1.3'
      scmMinTlsVersion: '1.3'
      ftpsState: 'Disabled'
      netFrameworkVersion: 'v8.0'
    }
    privateEndpoints: [
      {
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[5].outputs.resourceId
                : privateDnsZoneAzureSites.id
            }
          ]
        }
        tags: tags
      }
      {
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[6].outputs.resourceId
                : privateDnsZoneAzureSitesScm.id
            }
          ]
        }
        tags: tags
      }
    ]
    tags: tags
  }
  dependsOn: [
    createStorageAccount
    createApplicationInsights
    createAppServicePlan
  ]
}

module updateKeyVaultFunctionAppRbac 'br/public:avm/res/key-vault/vault/access-policy:0.1.0' = {
  scope: resourceGroup(createWithKeyVault ? resourceGroupName : existingKeyVaultResourceGroup)
  params: {
    keyVaultName: selectedKeyVaultName
    accessPolicies: [
      {
        objectId: createFunctionApp.outputs.systemAssignedMIPrincipalId!
        permissions: {
          certificates: [
            'get'
            'list'
            'update'
            'create'
            'delete'
          ]
        }
      }
    ]
  }
  dependsOn: [
    createFunctionApp
  ]
}

module roleAssignmentPublicDnsZone 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = [
  for dnsZoneResourceId in azurePublicDnsZones: if (enablePublicDnsRoleAssignment) {
    name: 'rbac-${uniqueString(dnsZoneResourceId)}'
    scope: resourceGroup(azurePublicDnsResourceGroup)
    params: {
      principalId: createFunctionApp.outputs.systemAssignedMIPrincipalId!
      roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/befefa01-2a29-4197-83a8-272ff33ce314' // DNS Zone Contributor
      resourceId: dnsZoneResourceId
    }
    dependsOn: [
      createFunctionApp
    ]
  }
]

module roleAssignmentPrivateDnsZone 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = [
  for dnsZoneResourceId in azurePrivateDnsZones: if (enablePrivateDnsRoleAssignment) {
    name: 'rbac-${uniqueString(dnsZoneResourceId)}'
    scope: resourceGroup(azurePrivateDnsResourceGroup)
    params: {
      principalId: createFunctionApp.outputs.systemAssignedMIPrincipalId!
      roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/b12aa53e-6015-4669-85d0-8515ebb3ae7f' // Private DNS Zone Contributor
      resourceId: dnsZoneResourceId
    }
    dependsOn: [
      createFunctionApp
    ]
  }
]

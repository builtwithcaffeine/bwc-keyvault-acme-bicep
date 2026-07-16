targetScope = 'subscription'

@description('Azure Tenant Id')
var tenantId = subscription().tenantId

@description('Customer name - used for naming resources')
@minLength(3)
@maxLength(5)
@metadata({ pattern: '^[a-z0-9]+$' })
param customerName string

@description('Azure Location')
param location string

@description('Azure Location Short Code')
@minLength(2)
@maxLength(3)
@metadata({ pattern: '^[a-z0-9]+$' })
param locationShortCode string

@description('Environment Type')
@allowed(['dev', 'acc', 'prod'])
param environmentType string

@description('Deployed By')
@minLength(3)
param deployedBy string

param tags object = {
  environmentType: environmentType
  deployedBy: deployedBy
  deployedDate: utcNow('yyyy-MM-dd')
}

//
// Parameters [Created Resources]

// Resource Group Name
var resourceGroupName = 'rg-x-${customerName}-kvacme-${environmentType}-${locationShortCode}'

var networkSecurityGroupName = 'nsg-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// Virtual Network Name
var virtualNetworkName = 'vnet-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// User Managed Identity Name
var userManagedIdentityName = 'id-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// Key Vault Name
var keyvaultName = 'kv-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// Storage Account Name
var storageAccountName = 'st${customerName}kvacme${environmentType}${locationShortCode}'

// Log Analytics Workspace Name
var logAnalyticsWorkspaceName = 'log-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// Application Insights Name
var applicationInsightsName = 'appi-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// Application Service Plan Name
var appServicePlanName = 'asp-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// Function App Name
var functionAppName = 'func-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// App Registration Name
var appRegistrationName = 'sp-${customerName}-kvacme-authentication-${environmentType}'

//
// Parameters [Existing Resources]
// Imported from parameters file or passed in at deployment time

@description('Shared Hub - Resource Group Name')
param sharedResourceGroupName string

// Azure Virtual Network

@description('Enable Create Virtual Network Module')
param enableCreateVirtualNetwork bool

@description('Enable Create Private Dns Zones')
param enableCreatePrivateDnsZones bool

@description('Virtual Network Address Prefix')
param virtualNetworkAddressPrefix string

@description('Virtual Network Subnet - Shared Resources')
param virtualNetworkSubnetShared string

@description('Virtual Network Subnet - App Service')
param virtualNetworkSubnetAppService string

@description('Existing Virtual Network Resource Group Name')
param existingVirtualNetworkResourceGroup string

@description('Existing Virtual Network Name')
param existingVirtualNetworkName string

@description('Existing Virtual Network Subnet - Shared Resources')
param existingVirtualNetworkSubnetSharedName string

@description('Existing Virtual Network Subnet - App Service')
param existingVirtualNetworkSubnetAppServiceName string

// Azure Key Vault

@description('Key Vault Access Policy - User Managed Identity')
var kvAccessPolicies = [
  {
    objectId: createUserManagedIdentity.outputs.principalId
    permissions: {
      secrets: [
        'get'
        'list'
      ]
      certificates: [
        'get'
        'list'
        'update'
        'create'
        'delete'
      ]
    }
    tenantId: tenantId
  }
]

// Acmebot Package URL

@description('Key Vault Base Url for ACME Bot')
var acmeKeyVaultUrlBase = 'https://${keyvaultName}${environment().suffixes.keyvaultDns}/'

@description('Acmebot Package Uri')
param acmebotPackageUri string

@description('Percentage of certificate lifetime remaining before renewal (0-100)')
@minValue(0)
@maxValue(100)
param acmeBotRenewBeforeExpiry int

@description('Use system DNS resolver for challenge verification (recommended for private DNS scenarios)')
param acmeBotUseSystemNameServer bool = false

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
  'https://emea.acme.atlas.globalsign.com/directory'
  'https://acme.zerossl.com/v2/DV90'
  'https://dv.acme-v02.api.pki.goog/directory'
  'https://acme.ssl.com/sslcom-dv-rsa'
  'https://acme.ssl.com/sslcom-dv-ecc'
])
@description('Lets Encrypt Public End point')
param acmeEndpoint string

@description('Azure Environment')
param acmeEnvironment string

@description('Key Vault ACME - Email Contact(s)')
param acmeContacts string

@description('Private Dns Zones Array Variable')
var privateDnsZonesArray = [
  'privatelink.vaultcore.azure.net'                       // [0]
  'privatelink.blob.${environment().suffixes.storage}'    // [1]
  'privatelink.file.${environment().suffixes.storage}'    // [2]
  'privatelink.table.${environment().suffixes.storage}'   // [3]
  'privatelink.queue.${environment().suffixes.storage}'   // [4]
  'privatelink.azurewebsites.net'                         // [5]
]

//
// Azure Resource - [Existing]

resource sharedVirtualNetwork 'Microsoft.Network/virtualNetworks@2025-07-01' existing = if (!enableCreateVirtualNetwork) {
  scope: resourceGroup(existingVirtualNetworkResourceGroup)
  name: existingVirtualNetworkName
}

resource existingVirtualNetworkSubnetShared 'Microsoft.Network/virtualNetworks/subnets@2025-07-01' existing = if (!enableCreateVirtualNetwork) {
  parent: sharedVirtualNetwork
  name: existingVirtualNetworkSubnetSharedName
}

resource existingVirtualNetworkSubnetAppService 'Microsoft.Network/virtualNetworks/subnets@2025-07-01' existing = if (!enableCreateVirtualNetwork) {
  parent: sharedVirtualNetwork
  name: existingVirtualNetworkSubnetAppServiceName
}

// Private End Point - Key Vault
resource privateDnsZoneKeyVault 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!enableCreatePrivateDnsZones) {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[0]
}

// Private End Point - Storage Account (Blob)
resource privateDnsZoneStorageBlob 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!enableCreatePrivateDnsZones) {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[1]
}

// Private End Point - Storage Account (File)
resource privateDnsZoneStorageFile 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!enableCreatePrivateDnsZones) {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[2]
}

// Private End Point - Storage Account (Table)
resource privateDnsZoneStorageTable 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!enableCreatePrivateDnsZones) {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[3]
}

// Private End Point - Storage Account (Queue)
resource privateDnsZoneStorageQueue 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!enableCreatePrivateDnsZones) {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[4]
}

// Private End Point - Web Site
resource privateDnsZoneAzureSites 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!enableCreatePrivateDnsZones) {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[5]
}

//
// Azure Resource Modules - [Create]
//

// Create Resource Group
module createResourceGroup 'br/public:avm/res/resources/resource-group:0.4.3' = {
  name: 'create-resource-group-${locationShortCode}'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// Create User Managed Identity
module createUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.1' = {
  name: 'create-user-managed-identity-${locationShortCode}'
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

module createNetworkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.3' = if (enableCreateVirtualNetwork) {
  name: 'create-nsg-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: networkSecurityGroupName
    location: location
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createVirtualNetwork 'br/public:avm/res/network/virtual-network:0.9.0' = if (enableCreateVirtualNetwork) {
  name: 'create-virtual-network-${locationShortCode}'
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
        networkSecurityGroupResourceId: createNetworkSecurityGroup!.outputs.resourceId
      }
      {
        name: 'snet-kvacme-appservice'
        addressPrefix: virtualNetworkSubnetAppService
        networkSecurityGroupResourceId: createNetworkSecurityGroup!.outputs.resourceId
        delegation: 'Microsoft.App/environments'
      }
    ]
    tags: tags
  }
  dependsOn: [
    createNetworkSecurityGroup
  ]
}

module createPrivateDnsZones 'br/public:avm/res/network/private-dns-zone:0.8.1' = [
  for privateDnsZone in privateDnsZonesArray: if (enableCreatePrivateDnsZones) {
    name: 'create-${replace(privateDnsZone, '.', '-')}-${locationShortCode}'
    scope: resourceGroup(resourceGroupName)
    params: {
      name: privateDnsZone
      location: 'global'
      virtualNetworkLinks: [
        {
          virtualNetworkResourceId: createVirtualNetwork!.outputs.resourceId
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
  name: 'create-entra-security-group-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    displayName: '${customerName} Key Vault ACME - Authentication - ${environmentType}'
    groupName: 'sec-${customerName}-keyvault-acme-auth-${environmentType}'
    mailNickname: 'sec-${customerName}-keyvault-acme-auth-${environmentType}'
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
  name: 'create-entra-app-registration-${locationShortCode}'
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
  name: 'create-entra-federated-credential-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    applicationId: createAppRegistration.outputs.uniqueName
    name: 'keyvault-acme-federated-credential-${environmentType}'
    issuer: '${environment().authentication.loginEndpoint}${tenantId}/v2.0'
    credentialDescription: 'Federated Identity Credential for Key Vault ACME - ${environmentType}'
    subject: createUserManagedIdentity.outputs.principalId
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
  dependsOn: [
    createAppRegistration
    createUserManagedIdentity
  ]
}

// Create Enterprise Application
module createServicePrincipal 'modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'create-entra-service-principal-${locationShortCode}'
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

// Create Key Vault
module createKeyVault 'br/public:avm/res/key-vault/vault:0.13.3' = {
  name: 'create-keyvault-${locationShortCode}'
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
          ? createVirtualNetwork!.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[0]!.outputs.resourceId
                : privateDnsZoneKeyVault.id
            }
          ]
        }
      }
    ]
    diagnosticSettings: [
      {
        workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
        logCategoriesAndGroups: [
          {
            category: 'AuditEvent'
          }
        ]
        metricCategories: [
          {
            category: 'AllMetrics'
          }
        ]
      }
    ]
    tags: tags
  }
  dependsOn: [
    createVirtualNetwork
  ]
}

module createStorageAccount 'br/public:avm/res/storage/storage-account:0.32.1' = {
  name: 'create-storage-account'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_ZRS'
    publicNetworkAccess: 'Disabled'
    allowSharedKeyAccess: false
    requireInfrastructureEncryption: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    blobServices: {
      containers: [
        {
          name: 'app-package-${functionAppName}'
          publicAccess: 'None'
        }
        {
          name: 'azure-webjobs-hosts'
          publicAccess: 'None'
        }
        {
          name: 'azure-webjobs-secrets'
          publicAccess: 'None'
        }
      ]
    }
    roleAssignments: [
      {
        principalId: createUserManagedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: createUserManagedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Queue Data Contributor'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: createUserManagedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Table Data Contributor'
        principalType: 'ServicePrincipal'
      }
    ]
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork!.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[1]!.outputs.resourceId //blob
                : privateDnsZoneStorageBlob.id
            }
          ]
        }
      }
      {
        service: 'file'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork!.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[2]!.outputs.resourceId // file
                : privateDnsZoneStorageFile.id
            }
          ]
        }
      }
      {
        service: 'table'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork!.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[3]!.outputs.resourceId // table
                : privateDnsZoneStorageTable.id
            }
          ]
        }
      }
      {
        service: 'queue'
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork!.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[4]!.outputs.resourceId // queue
                : privateDnsZoneStorageQueue.id
            }
          ]
        }
      }
    ]
    tags: tags
  }
  dependsOn: [
    createKeyVault
  ]
}

module createLogAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.15.1' = {
  name: 'create-log-analytics-workspace-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    dataRetention: 90
    skuName: 'PerGB2018'
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createApplicationInsights 'br/public:avm/res/insights/component:0.7.2' = {
  name: 'create-application-insights'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: applicationInsightsName
    location: location
    workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
    disableLocalAuth: true
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Monitoring Metrics Publisher'
        principalType: 'ServicePrincipal'
        principalId: createUserManagedIdentity.outputs.principalId
      }
    ]
    tags: tags
  }
  dependsOn: [
    createLogAnalyticsWorkspace
  ]
}

module createAppServicePlan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  name: 'create-app-service-plan-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: appServicePlanName
    location: location
    kind: 'linux'
    skuName: 'FC1'
    skuCapacity: 2
    tags: tags
  }
  dependsOn: [
    createApplicationInsights
  ]
}

module createFunctionApp 'br/public:avm/res/web/site:0.23.1' = {
  name: 'create-function-app-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: functionAppName
    location: location
    kind: 'functionapp,linux'
    serverFarmResourceId: createAppServicePlan.outputs.resourceId
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    outboundVnetRouting: {
      applicationTraffic: true
      contentShareTraffic: true
    }
    virtualNetworkSubnetResourceId: enableCreateVirtualNetwork
      ? createVirtualNetwork!.outputs.subnetResourceIds[1]
      : existingVirtualNetworkSubnetAppService.id
    keyVaultAccessIdentityResourceId: createUserManagedIdentity.outputs.resourceId
    managedIdentities: {
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
        name: 'appsettings'
        properties: {
          // Function App Values
          FUNCTIONS_EXTENSION_VERSION: '~4'

          // Application Insights
          APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${createUserManagedIdentity.outputs.clientId};Authorization=AAD'
          APPLICATIONINSIGHTS_CONNECTION_STRING: createApplicationInsights.outputs.connectionString

          // Storage (Managed Identity - no shared key access)
          AzureWebJobsStorage__accountName: storageAccountName
          AzureWebJobsStorage__credential: 'managedidentity'
          AzureWebJobsStorage__clientId: createUserManagedIdentity.outputs.clientId

          // Enterprise App Values
          WEBSITE_AUTH_AAD_ALLOWED_TENANTS: tenantId
          OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID: createUserManagedIdentity.outputs.clientId
          // https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad?tabs=workforce-configuration#use-a-managed-identity-instead-of-a-secret-preview

          // Key Vault ACME Values
          Acmebot__RenewBeforeExpiry: string(acmeBotRenewBeforeExpiry)
          Acmebot__AzureDns__SubscriptionId: acmeAzurePublicDnsSubscriptionId
          Acmebot__AzurePrivateDns__SubscriptionId: acmeAzurePrivateDnsSubscriptionId
          Acmebot__ManagedIdentityClientId: createUserManagedIdentity.outputs.clientId
          Acmebot__Endpoint: acmeEndpoint
          Acmebot__Environment: acmeEnvironment
          Acmebot__VaultBaseUrl: acmeKeyVaultUrlBase
          Acmebot__Contacts: acmeContacts
          Acmebot__UseSystemNameServer: string(acmeBotUseSystemNameServer)
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
                openIdIssuer: '${environment().authentication.loginEndpoint}${tenantId}/v2.0'
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
    functionAppConfig: {
      runtime: {
        name: 'dotnet-isolated'
        version: '10.0'
      }
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${createStorageAccount.outputs.serviceEndpoints.blob}app-package-${functionAppName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: createUserManagedIdentity.outputs.resourceId
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 2048
        maximumInstanceCount: 100
      }
    }
    siteConfig: {
      alwaysOn: false
      ftpsState: 'Disabled'
      http20Enabled: true
      minTlsVersion: '1.3'
      scmMinTlsVersion: '1.3'
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
    }
    privateEndpoints: [
      {
        subnetResourceId: enableCreateVirtualNetwork
          ? createVirtualNetwork!.outputs.subnetResourceIds[0]
          : existingVirtualNetworkSubnetShared.id
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: enableCreateVirtualNetwork
                ? createPrivateDnsZones[5]!.outputs.resourceId
                : privateDnsZoneAzureSites.id
            }
          ]
        }
        tags: tags
      }
    ]
    tags: tags
  }
}

// Deploy Acmebot package from GitHub releases into the Flex Consumption blob container
module deployFunctionAppPackage 'modules/app/site/extension/main.bicep' = {
  name: 'deploy-function-app-package-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    functionAppName: functionAppName
    packageUri: acmebotPackageUri
  }
  dependsOn: [
    createFunctionApp
  ]
}

module roleAssignmentPublicDnsZone 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = [
  for dnsZoneResourceId in azurePublicDnsZones: if (enablePublicDnsRoleAssignment) {
    name: 'rbac-${uniqueString(dnsZoneResourceId)}-${locationShortCode}'
    scope: resourceGroup(acmeAzurePublicDnsSubscriptionId, azurePublicDnsResourceGroup)
    params: {
      principalId: createUserManagedIdentity.outputs.principalId
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
    name: 'rbac-${uniqueString(dnsZoneResourceId)}-${locationShortCode}'
    scope: resourceGroup(acmeAzurePrivateDnsSubscriptionId, azurePrivateDnsResourceGroup)
    params: {
      principalId: createUserManagedIdentity.outputs.principalId
      roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/b12aa53e-6015-4669-85d0-8515ebb3ae7f' // Private DNS Zone Contributor
      resourceId: dnsZoneResourceId
    }
    dependsOn: [
      createFunctionApp
    ]
  }
]

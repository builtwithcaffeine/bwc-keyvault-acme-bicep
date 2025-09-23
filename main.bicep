targetScope = 'subscription'

//
@description('Azure Subscription Id')
var subscriptionId = subscription().subscriptionId

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
param resourceGroupName string = 'rg-x-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param keyvaultName string = 'kv-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param userManagedIdentityName string = 'id-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param logAnalyticsWorkspaceName string = 'log-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param storageAccountName string = 'st${customerName}kvacme${environmentType}${locationShortCode}'
param applicationInsightsName string = 'appi-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param appServicePlanName string = 'asp-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param functionAppName string = 'func-${customerName}-kvacme-${environmentType}-${locationShortCode}'

//
// Parameters [Existing Resources]
// Imported from parameters file or passed in at deployment time

@description('Shared Hub - Resource Group Name')
param sharedResourceGroupName string

@description('Shared Virtual Network Name')
param sharedVirtualNetworkName string

// App Service Plan
param appServiceKind string = 'linux'
param appServiceSkuName string = 'B1'

//
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

@description('Azure Public Dns Resource Group  ')
param azurePublicDnsResourceGroup string

@description('Azure Public Dns Resource Id')
param azurePublicDnsZones array

@description('Enable Private Dns Role Assignment Module')
param enablePrivateDnsRoleAssignment bool

@description('Azure Private Dns Resource Group  ')
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
param acmeContacts string

//
@description('Key Vault Name Variable')
var selectedKeyVaultName = createWithKeyVault ? keyvaultName : existingKeyVaultName

var privateDnsZonesArray = [
  'privatelink.vaultcore.azure.net'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.azurewebsites.net'
  'scm.privatelink.azurewebsites.net'
]

//
// Azure Resource - [Existing]
resource sharedVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: sharedVirtualNetworkName
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = if (!createWithKeyVault) {
  scope: resourceGroup(existingKeyVaultResourceGroup)
  name: existingKeyVaultName
}

// Private End Point - Key Vault
resource privDnsZoneKeyVault 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[0]
}

// Private End Point - Storage Account (Blob)
resource privDnsZoneStorageBlob 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[1]
}

// Private End Point - Storage Account (Table)
resource privDnsZoneStorageTable 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[2]
}

// Private End Point - Storage Account (File)
resource privDnsZoneStorageFile 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[3]
}

// Private End Point - Storage Account (Queue)
resource privDnsZoneStorageQueue 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[4]
}

// Private End Point - Web Site
resource privDnsZoneAzureSites 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[5]
}

// Private End Point - Web Site SCM
resource privDnsZoneAzureSitesSCM 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(sharedResourceGroupName)
  name: privateDnsZonesArray[6]
}

//
// Azure Resource Modules - [Create]
//

// Create Resource Group
module createResourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: 'create-resource-group'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// Create Entra Security Group
module createEntraSecurityGroup 'modules/microsoft-graph/groups/main.bicep' = {
  name: 'create-entra-security-group'
  scope: resourceGroup(resourceGroupName)
  params: {
    displayName: 'Key Vault ACME - Authentication - ${environmentType}'
    groupName: 'sec-keyvault-acme-auth-${environmentType}'
    mailNickname: 'sec-keyvault-acme-auth-${environmentType}'
    groupDescription: 'Key Vault ACME - Security Group'
    ownerIds: [
    ]
    memberIds: [
    ]
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
    appName: 'sp-kvacme-authentication-${environmentType}'
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
module createUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
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
        subnetResourceId: sharedVirtualNetwork.properties.subnets[1].id // snet-private
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privDnsZoneKeyVault.id
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

module createStorageAccount 'br/public:avm/res/storage/storage-account:0.26.2' = {
  name: 'create-storage-account'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_ZRS'
    tags: tags
    publicNetworkAccess: 'Disabled'
    secretsExportConfiguration: {
      accessKey1Name: 'accessKey1'
      accessKey2Name: 'accessKey2'
      connectionString1Name: 'connectionString1'
      connectionString2Name: 'connectionString2'
      keyVaultResourceId: createWithKeyVault ? createKeyVault!.outputs.resourceId : existingKeyVault!.id
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    fileServices: {
      shares: [
        {
          name: functionAppName
          ShareQuota: 10
        }
      ]
    }
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: sharedVirtualNetwork.properties.subnets[1].id // snet-private
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privDnsZoneStorageBlob.id
            }
          ]
        }
      }
      {
        service: 'file'
        subnetResourceId: sharedVirtualNetwork.properties.subnets[1].id // snet-private
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privDnsZoneStorageFile.id
            }
          ]
        }
      }
      {
        service: 'table'
        subnetResourceId: sharedVirtualNetwork.properties.subnets[1].id // snet-private
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privDnsZoneStorageTable.id
            }
          ]
        }
      }
      {
        service: 'queue'
        subnetResourceId: sharedVirtualNetwork.properties.subnets[1].id // snet-private
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privDnsZoneStorageQueue.id
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

module createLogAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
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

module createApplicationInsights 'br/public:avm/res/insights/component:0.6.0' = {
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

module createFunctionApp 'br/public:avm/res/web/site:0.19.3' = {
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
    virtualNetworkSubnetResourceId: sharedVirtualNetwork.properties.subnets[2].id
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
          
          // Ensure compatibility with pre-built packages
          WEBSITE_USE_PLACEHOLDER: '0'
          
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
          'Acmebot__MitigateChainOrder': 'true'
          'Acmebot__AzureDns__SubscriptionId': acmeAzurePublicDnsSubscriptionId
          'Acmebot__AzurePrivateDns__SubscriptionId': acmeAzurePrivateDnsSubscriptionId
          'Acmebot__Endpoint': acmeEndpoint
          'Acmebot__Environment': acmeEnvironment
          'Acmebot__VaultBaseUrl': acmeKeyVaultUrlBase
          'Acmebot__Contacts': acmeContacts
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
      linuxFxVersion: 'DOTNET|8.0'
      minTlsVersion: '1.3'
      scmMinTlsVersion: '1.3'
      ftpsState: 'Disabled'
    }
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privDnsZoneAzureSites.id
            }
          ]
        }
        tags: tags
        subnetResourceId: sharedVirtualNetwork.properties.subnets[1].id // snet-private
      }
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privDnsZoneAzureSitesSCM.id
            }
          ]
        }
        tags: tags
        subnetResourceId: sharedVirtualNetwork.properties.subnets[1].id // snet-private
      }
    ]
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

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

@description('Identity or pipeline responsible for the deployment')
@minLength(3)
param deployedBy string

@description('Additional resource tags. Values override the CAF-aligned baseline tags.')
param tags object = {}

var resourceTags = union({
  environmentType: environmentType
  workload: 'kvacme'
  managedBy: 'Bicep'
  deployedBy: deployedBy
}, tags)

//
// Parameters [Created Resources]

// Resource Group Name
var resourceGroupName = 'rg-x-${customerName}-kvacme-${environmentType}-${locationShortCode}'

var networkSecurityGroupName = 'nsg-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// Virtual Network Name
var virtualNetworkName = 'vnet-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// User Managed Identity Name
var userManagedIdentityArray = [
  'id-${customerName}-kvacme-${environmentType}-${locationShortCode}'
  'id-${customerName}-kvacme-cert-manager-${environmentType}-${locationShortCode}'
]

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

@description('Key Vault Access Policies')
var kvAccessPolicies = [
  {
    objectId: createUserManagedIdentity[0].outputs.principalId // Acmebot Managed Identity
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
  {
    objectId: createUserManagedIdentity[1].outputs.principalId // Key Vault ACME - Cert Manager Managed Identity
    permissions: {
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
  {
    objectId: createKeyVaultSecurityGroup.outputs.groupId // Entra Id Group for Certificate Listing
    permissions: {
      secrets: [
        'get'
        'list'
      ]
      certificates: [
        'get'
        'list'
      ]
    }
  }
]

// Acmebot Package URL

@description('Key Vault Base Url for ACME Bot')
var acmeKeyVaultUrlBase = 'https://${keyvaultName}${environment().suffixes.keyvaultDns}/'

@description('Acmebot release tag used to construct the package URI. Use latest, 5.0.0, or v5.0.0.')
@minLength(1)
param acmebotReleaseTag string = 'latest'

var normalizedAcmebotReleaseTag = startsWith(toLower(acmebotReleaseTag), 'v')
  ? acmebotReleaseTag
  : 'v${acmebotReleaseTag}'

#disable-next-line no-hardcoded-env-urls
var acmebotPackageUri = toLower(acmebotReleaseTag) == 'latest'
  ? 'https://github.com/polymind-inc/acmebot/releases/latest/download/acmebot.zip'
  : 'https://github.com/polymind-inc/acmebot/releases/download/${normalizedAcmebotReleaseTag}/acmebot.zip'

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

// GitHub Actions OIDC Federation - Acmebot Managed Identity

@description('Enable a GitHub Actions federated identity credential on the Acmebot managed identity (userManagedIdentityArray[0]), so workflows can authenticate to Azure without secrets.')
param enableGitHubActionsFederation bool = false

@description('GitHub repository in "owner/repo" format used for the federated credential subject')
param gitHubRepository string = ''

@description('Immutable numeric GitHub owner Id. When supplied together with gitHubRepositoryId, the federated credential subject uses GitHub\'s immutable "owner@ownerId/repo@repoId" format, which is not affected by repository renames/transfers. See https://learn.microsoft.com/entra/workload-id/workload-identities-github-immutable-subjects')
param gitHubRepositoryOwnerId string = ''

@description('Immutable numeric GitHub repository Id. See gitHubRepositoryOwnerId.')
param gitHubRepositoryId string = ''

@description('GitHub Actions federation subject type used to scope the credential')
@allowed(['branch', 'environment', 'pull_request', 'tag'])
param gitHubFederationSubjectType string = 'branch'

@description('Branch, environment, or tag name used to build the federation subject (ignored for pull_request)')
param gitHubFederationSubjectValue string = 'main'

var gitHubRepositoryParts = split(gitHubRepository, '/')
var useImmutableGitHubSubject = !empty(gitHubRepositoryOwnerId) && !empty(gitHubRepositoryId)
var gitHubFederationRepository = useImmutableGitHubSubject
  ? '${gitHubRepositoryParts[0]}@${gitHubRepositoryOwnerId}/${gitHubRepositoryParts[1]}@${gitHubRepositoryId}'
  : gitHubRepository

var gitHubFederationSubject = gitHubFederationSubjectType == 'branch'
  ? 'repo:${gitHubFederationRepository}:ref:refs/heads/${gitHubFederationSubjectValue}'
  : gitHubFederationSubjectType == 'tag'
      ? 'repo:${gitHubFederationRepository}:ref:refs/tags/${gitHubFederationSubjectValue}'
      : gitHubFederationSubjectType == 'environment'
          ? 'repo:${gitHubFederationRepository}:environment:${gitHubFederationSubjectValue}'
          : 'repo:${gitHubFederationRepository}:pull_request'

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

resource existingVirtualNetworkSubnetShared 'Microsoft.Network/virtualNetworks/subnets@2025-09-01' existing = if (!enableCreateVirtualNetwork) {
  parent: sharedVirtualNetwork
  name: existingVirtualNetworkSubnetSharedName
}

resource existingVirtualNetworkSubnetAppService 'Microsoft.Network/virtualNetworks/subnets@2025-09-01' existing = if (!enableCreateVirtualNetwork) {
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
module createResourceGroup 'br/public:avm/res/resources/resource-group:0.4.4' = {
  name: 'create-resource-group-${locationShortCode}'
  params: {
    name: resourceGroupName
    location: location
    tags: resourceTags
  }
}

// Create Entra Security Group - Key Vault Certificate [Get - List]
module createKeyVaultSecurityGroup '../modules/microsoft-graph/groups/main.bicep' = {
  name: 'create-entra-keyvault-security-group-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    displayName: 'KVACME - Certificate Reader Role RBAC - ${toUpper(environmentType)}'
    groupName: 'sec-${customerName}-keyvault-acme-kv-access-${environmentType}'
    mailNickname: 'sec-${customerName}-keyvault-acme-kv-access-${environmentType}'
    groupDescription: 'Provides List/Get permission for Users'
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

// Create Entra Security Group - Enterprise App SSO
module createEntraSecurityGroup '../modules/microsoft-graph/groups/main.bicep' = {
  name: 'create-entra-security-group-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    displayName: 'KVACME - SSO Authentication - ${toUpper(environmentType)}'
    groupName: 'sec-${customerName}-keyvault-acme-auth-${environmentType}'
    mailNickname: 'sec-${customerName}-keyvault-acme-auth-${environmentType}'
    groupDescription: 'Key Vault ACME - SSO Authentication Security Group'
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
module createAppRegistration '../modules/microsoft-graph/applications/main.bicep' = {
  name: 'create-entra-app-registration-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appName: 'app-${customerName}-kvacme-authentication-${environmentType}'
    displayName: 'Key Vault ACME - Authentication - ${toUpper(environmentType)}'
    appDescription: 'App Registration for Key Vault ACME'
    homePageUrl: 'https://${functionAppName}.azurewebsites.net'
    webRedirectUris: [
      'https://${functionAppName}.azurewebsites.net/.auth/login/aad/callback'
    ]
    enableIdTokenIssuance: true
    requiredResourceAccess: [
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
        ]
      }
    ]
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createFederatedCredential '../modules/microsoft-graph/applications/federatedIdentityCredentials/main.bicep' = {
  name: 'create-entra-federated-credential-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    applicationId: createAppRegistration.outputs.uniqueName
    name: 'keyvault-acme-federated-credential-${environmentType}'
    issuer: '${environment().authentication.loginEndpoint}${tenantId}/v2.0'
    credentialDescription: 'Federated Identity Credential for Key Vault ACME - ${environmentType}'
    subject: createUserManagedIdentity[0].outputs.principalId
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
module createServicePrincipal '../modules/microsoft-graph/servicePrincipals/main.bicep' = {
  name: 'create-entra-service-principal-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appId: createAppRegistration.outputs.applicationId
    // displayName intentionally omitted - Graph requires it to exactly match the linked
    // application's displayName, so it inherits from createAppRegistration automatically.
    homepage: 'https://${functionAppName}.azurewebsites.net'
    accountEnabled: true
    appRoleAssignmentRequired: true

  }
  dependsOn: [
    createAppRegistration
  ]
}

// Create User Managed Identity
module createUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = [
  for userManagedIdentityName in userManagedIdentityArray: {
    name: 'create-umi-${userManagedIdentityName}-${locationShortCode}'
    scope: resourceGroup(resourceGroupName)
    params: {
      name: userManagedIdentityName
      location: location
      tags: resourceTags
    }
    dependsOn: [
      createResourceGroup
    ]
  }
]



// GitHub Actions OIDC federation on the Acmebot managed identity - lets workflows (e.g. update-acmebot-function-app.yml) authenticate without a client secret
module createGitHubActionsFederatedCredential '../modules/identity/federatedIdentityCredential/main.bicep' = if (enableGitHubActionsFederation) {
  name: 'create-github-actions-federated-credential-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    userAssignedIdentityName: userManagedIdentityArray[0]
    name: 'github-action-federation-${gitHubFederationSubjectType}'
    issuer: 'https://token.actions.githubusercontent.com'
    subject: gitHubFederationSubject
  }
  dependsOn: [
    createUserManagedIdentity
  ]
}


module createNetworkSecurityGroup 'br/public:avm/res/network/network-security-group:0.5.3' = if (enableCreateVirtualNetwork) {
  name: 'create-network-security-group-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: networkSecurityGroupName
    location: location
    tags: resourceTags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createVirtualNetwork 'br/public:avm/res/network/virtual-network:0.10.2' = if (enableCreateVirtualNetwork) {
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
    tags: resourceTags
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
          virtualNetworkResourceId: enableCreateVirtualNetwork
            ? createVirtualNetwork!.outputs.resourceId
            : sharedVirtualNetwork.id
        }
      ]
      tags: resourceTags
    }
    dependsOn: [
      createVirtualNetwork
    ]
  }
]

// Create Key Vault
module createKeyVault 'br/public:avm/res/key-vault/vault:0.14.0' = {
  name: 'create-keyvault-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: keyvaultName
    location: location
    sku: 'standard'
    enableVaultForDeployment: false
    enableVaultForTemplateDeployment: false
    enableVaultForDiskEncryption: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: false
    enableRbacAuthorization: false
    accessPolicies: kvAccessPolicies
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
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
    roleAssignments: [
      {
        principalId: createUserManagedIdentity[1].outputs.principalId //  'id-${customerName}-kvacme-cert-manager-${environmentType}-${locationShortCode}'
        roleDefinitionIdOrName: 'Key Vault Reader'
        principalType: 'ServicePrincipal'
      }
    ]
    tags: resourceTags
  }
  dependsOn: [
    createVirtualNetwork
  ]
}

module createStorageAccount 'br/public:avm/res/storage/storage-account:0.33.0' = {
  name: 'create-storage-account'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_ZRS'
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    allowCrossTenantReplication: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    requireInfrastructureEncryption: true
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
    blobServices: {
      containerDeleteRetentionPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 14
      deleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 14
      isVersioningEnabled: true
      versionDeletePolicyDays: 30
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
      diagnosticSettings: [
        {
          workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
        }
      ]
    }
    fileServices: {
      diagnosticSettings: [
        {
          workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
        }
      ]
    }
    queueServices: {
      diagnosticSettings: [
        {
          workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
        }
      ]
    }
    tableServices: {
      diagnosticSettings: [
        {
          workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
        }
      ]
    }
    roleAssignments: [
      {
        principalId: createUserManagedIdentity[0].outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: createUserManagedIdentity[0].outputs.principalId
        roleDefinitionIdOrName: 'Storage Queue Data Contributor'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: createUserManagedIdentity[0].outputs.principalId
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
    diagnosticSettings: [
      {
        workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
      }
    ]
    tags: resourceTags
  }
  dependsOn: [
    createKeyVault
  ]
}

module createLogAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.16.1' = {
  name: 'create-log-analytics-workspace-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    dataRetention: 90
    skuName: 'PerGB2018'
    features: {
      disableLocalAuth: true
    }
    tags: resourceTags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createApplicationInsights 'br/public:avm/res/insights/component:0.8.0' = {
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
        principalId: createUserManagedIdentity[0].outputs.principalId
      }
    ]
    tags: resourceTags
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
    tags: resourceTags
  }
  dependsOn: [
    createApplicationInsights
  ]
}

module createFunctionApp 'br/public:avm/res/web/site:0.24.0' = {
  name: 'create-function-app-${locationShortCode}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: functionAppName
    location: location
    kind: 'functionapp,linux'
    serverFarmResourceId: createAppServicePlan.outputs.resourceId
    httpsOnly: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Disabled'
    outboundVnetRouting: {
      applicationTraffic: true
      contentShareTraffic: true
    }
    virtualNetworkSubnetResourceId: enableCreateVirtualNetwork
      ? createVirtualNetwork!.outputs.subnetResourceIds[1]
      : existingVirtualNetworkSubnetAppService.id
    keyVaultAccessIdentityResourceId: createUserManagedIdentity[0].outputs.resourceId
    managedIdentities: {
      userAssignedResourceIds: [
        createUserManagedIdentity[0].outputs.resourceId
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
          APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${createUserManagedIdentity[0].outputs.clientId};Authorization=AAD'
          APPLICATIONINSIGHTS_CONNECTION_STRING: createApplicationInsights.outputs.connectionString

          // Storage (Managed Identity - no shared key access)
          AzureWebJobsStorage__accountName: storageAccountName
          AzureWebJobsStorage__credential: 'managedidentity'
          AzureWebJobsStorage__clientId: createUserManagedIdentity[0].outputs.clientId

          // Enterprise App Values
          WEBSITE_AUTH_AAD_ALLOWED_TENANTS: tenantId
          OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID: createUserManagedIdentity[0].outputs.clientId
          // https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad?tabs=workforce-configuration#use-a-managed-identity-instead-of-a-secret-preview

          // Key Vault ACME Values
          Acmebot__RenewBeforeExpiry: string(acmeBotRenewBeforeExpiry)
          Acmebot__AzureDns__SubscriptionId: acmeAzurePublicDnsSubscriptionId
          Acmebot__AzurePrivateDns__SubscriptionId: acmeAzurePrivateDnsSubscriptionId
          Acmebot__ManagedIdentityClientId: createUserManagedIdentity[0].outputs.clientId
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
            userAssignedIdentityResourceId: createUserManagedIdentity[0].outputs.resourceId
          }
        }
      }
      scaleAndConcurrency: {
        instanceMemoryMB: 2048
        maximumInstanceCount: 100
      }
    }
    diagnosticSettings: [
      {
        workspaceResourceId: createLogAnalyticsWorkspace.outputs.resourceId
      }
    ]
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
        tags: resourceTags
      }
    ]
    tags: resourceTags
  }
}

// Deploy Acmebot package from GitHub releases into the Flex Consumption blob container
module deployFunctionAppPackage '../modules/app/site/extension/main.bicep' = {
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
      principalId: createUserManagedIdentity[0].outputs.principalId
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
      principalId: createUserManagedIdentity[0].outputs.principalId
      roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/b12aa53e-6015-4669-85d0-8515ebb3ae7f' // Private DNS Zone Contributor
      resourceId: dnsZoneResourceId
    }
    dependsOn: [
      createFunctionApp
    ]
  }
]

// GitHub Actions federation values - surfaced so the deployment wrapper script can print the AZURE_CLIENT_ID / AZURE_TENANT_ID secrets to configure
output gitHubActionsFederationEnabled bool = enableGitHubActionsFederation
output gitHubActionsFederationClientId string = createUserManagedIdentity[0].outputs.clientId
output gitHubActionsFederationTenantId string = tenantId
output gitHubActionsFederationSubject string = enableGitHubActionsFederation ? gitHubFederationSubject : ''

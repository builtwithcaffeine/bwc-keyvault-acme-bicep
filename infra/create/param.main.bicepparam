using './main.bicep'

// Default Parameters
param customerName = 'bwc'
param environmentType = 'dev'
param location = 'westeurope'
param locationShortCode = 'weu'
param deployedBy = 'labadmin@builtwithcaffeine.cloud'

// Azure Subscription Id
var subscriptionId = 'ecba0e28-5657-4e2b-a5f5-9c3873893d3b'

//
// Azure Network
//
// networkTopology selects one of three supported configurations:
//
//   standalone - Creates a Virtual Network and its own private DNS zones. Self-contained,
//                no hub connectivity. Only the spoke* parameters below are used.
//
//   hubSpoke   - Creates a Virtual Network and peers it (both directions) to an existing
//                shared hub. Uses the hub-hosted private DNS zones. Requires the spoke*,
//                sharedHub* and privateDnsZone* parameters.
//
//   existing   - Brings your own Virtual Network and subnets, and uses existing private DNS
//                zones. Requires the existing* and privateDnsZone* parameters.
//
param networkTopology = 'hubSpoke'

// Azure Network - Private DNS Zones [hubSpoke, existing]
param privateDnsZoneSubscriptionId = subscriptionId
param privateDnsZoneResourceGroupName = 'rg-bwc-shared-hub-prod-weu'
param enablePrivateDnsZoneVnetLink = true

// Azure Network - Spoke Virtual Network [standalone, hubSpoke]
param spokeVirtualNetworkAddressPrefix = '10.1.0.0/24' // 254 Addresses
param spokeSubnetPrivateEndpointPrefix = '10.1.0.0/28' // 16 Addresses
param spokeSubnetAppServicePrefix = '10.1.0.32/27' // 32 Addresses

// Azure Network - Shared Hub [hubSpoke]
param sharedHubSubscriptionId = subscriptionId
param sharedHubResourceGroupName = 'rg-bwc-shared-hub-prod-weu'
param sharedHubVirtualNetworkName = 'vnet-bwc-shared-hub-prod-weu'

// Azure Network - Existing Virtual Network [existing]
param existingSubscriptionId = subscriptionId
param existingResourceGroupName = 'rg-bwc-shared-hub-prod-weu'
param existingVirtualNetworkName = 'vnet-bwc-shared-hub-prod-weu'
param existingSubnetPrivateEndpointName = 'snet-shared-hub-prod-weu'
param existingSubnetAppServiceName = 'snet-appservice-hub-prod-weu'

//
// Azure DNS Zones
param enablePublicDnsRoleAssignment = true
param azurePublicDnsResourceGroup = 'rg-bwc-dns-prod-weu'
param azurePublicDnsZones = [
  '/subscriptions/${subscriptionId}/resourceGroups/${azurePublicDnsResourceGroup}/providers/Microsoft.Network/dnszones/az.builtwithcaffeine.cloud'
  '/subscriptions/${subscriptionId}/resourceGroups/${azurePublicDnsResourceGroup}/providers/Microsoft.Network/dnszones/lab.builtwithcaffeine.cloud'
  '/subscriptions/${subscriptionId}/resourceGroups/${azurePublicDnsResourceGroup}/providers/Microsoft.Network/dnszones/dev.builtwithcaffeine.cloud'
]

param enablePrivateDnsRoleAssignment = false
param azurePrivateDnsResourceGroup = 'rg-bwc-dns-prod-weu'
param azurePrivateDnsZones = [
  '/subscriptions/${subscriptionId}/resourceGroups/${azurePrivateDnsResourceGroup}/providers/Microsoft.Network/privateDnsZones/internal.bwc.cloud'
]

//
// Key Vault ACME Values

// Deploy the latest GitHub release asset by default.
// Set this to 'latest', '5.0.0', or 'v5.0.0' when you want to pin a release.
param acmebotReleaseTag = '5.1.4'

// @description('ACME Azure Public DNS Subscription ID')
param acmeAzurePublicDnsSubscriptionId = subscriptionId

// @description('ACME Azure Private DNS Subscription ID')
param acmeAzurePrivateDnsSubscriptionId = subscriptionId

// @description('ACME Bot Renew Before Expiry - percentage of certificate lifetime remaining (0-100)')
param acmeBotRenewBeforeExpiry = 30

// @description('Use system DNS resolver for challenge verification (private DNS helper)')
param acmeBotUseSystemNameServer = false

// @description('ACME Endpoint')
param acmeEndpoint = 'https://acme-v02.api.letsencrypt.org/directory'

// @description('Azure Environment')
param acmeEnvironment = 'AzureCloud'

// @description('ACME Contacts Email Address')
param acmeContacts = 'alerts@builtwithcaffeine.cloud'

//
// GitHub Actions OIDC Federation - Acmebot Managed Identity
// Enable to let GitHub Actions workflows (e.g. update-acmebot-function-app.yml) authenticate via the
// Acmebot managed identity's client-id/tenant-id, with no client secret required.
param enableGitHubActionsFederation = true

// For Windows: winget install --id 'GitHub.cli'
// CLI Authentication: gh auth login
// Find them via: gh api repos/{owner}/{repo} --jq '.id, .owner.id'
param gitHubRepositoryId = '905440910'
param gitHubRepositoryOwnerId = '141853123'
param gitHubFederationSubjectType = 'branch'
param gitHubFederationSubjectValue = 'main'
param gitHubRepository = 'builtwithcaffeine/bwc-keyvault-acme-bicep'

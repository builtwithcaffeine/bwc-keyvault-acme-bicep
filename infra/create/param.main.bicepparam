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
// Azure Existing Resource
param sharedResourceGroupName = 'rg-bwc-dns-prod-weu'

// Azure Network
param enableCreatePrivateDnsZones = true
param enableCreateVirtualNetwork = true

// Azure Network - New Virtual Network
param virtualNetworkAddressPrefix = '10.0.0.0/24' // 254 Addresses
param virtualNetworkSubnetShared = '10.0.0.0/28' // 16 Addresses
param virtualNetworkSubnetAppService = '10.0.0.32/27' // 32 Addresses

// Azure Network - Existing Virtual Network
param existingVirtualNetworkResourceGroup = 'rg-bwc-dns-prod-weu'
param existingVirtualNetworkName = 'vnet-bwc-shared-hub-prod-weu'
param existingVirtualNetworkSubnetSharedName = 'snet-shared-hub-prod-weu'
param existingVirtualNetworkSubnetAppServiceName = 'snet-appservice-hub-prod-weu'

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

using './main.bicep'

// Default Parameters
param customerName = 'bwc'
param environmentType = 'dev'
param location = 'westeurope'
param locationShortCode = 'weu'
param deployedBy = 'labadmin@builtwithcaffeine.cloud'

//
// Azure Existing Resource
param sharedResourceGroupName = 'rg-builtwithcaffeine-hub-weu'

// Azure Network
param enableCreatePrivateDnsZones = true

// Azure Network - New Virtual Network
param enableCreateVirtualNetwork = true
param virtualNetworkAddressPrefix = '10.0.0.0/24' // 254 Addresses
param virtualNetworkSubnetShared = '10.0.0.0/28' // 16 Addresses
param virtualNetworkSubnetAppService = '10.0.0.16/28' // 16 Addresses

// Azure Network - Existing Virtual Network
param existingVirtualNetworkResourceGroup = 'rg-builtwithcaffeine-hub-weu'
param existingVirtualNetworkName = 'vnet-bwc-shared-hub-prod-weu'
param existingVirtualNetworkSubnetSharedName = 'snet-shared-hub-prod-weu'
param existingVirtualNetworkSubnetAppServiceName = 'snet-appservice-hub-prod-weu'

//
// Azure DNS Zones
param enablePublicDnsRoleAssignment = true
param azurePublicDnsResourceGroup = 'rg-builtwithcaffeine-hub-weu'
param azurePublicDnsZones = [
  '/subscriptions/b67e1026-b589-41e2-b41f-73f8803f71a0/resourceGroups/rg-builtwithcaffeine-hub-weu/providers/Microsoft.Network/dnszones/az.builtwithcaffeine.cloud'
  '/subscriptions/b67e1026-b589-41e2-b41f-73f8803f71a0/resourceGroups/rg-builtwithcaffeine-hub-weu/providers/Microsoft.Network/dnszones/lab.builtwithcaffeine.cloud'
  '/subscriptions/b67e1026-b589-41e2-b41f-73f8803f71a0/resourceGroups/rg-builtwithcaffeine-hub-weu/providers/Microsoft.Network/dnszones/dev.builtwithcaffeine.cloud'
]

param enablePrivateDnsRoleAssignment = true
param azurePrivateDnsResourceGroup = 'rg-builtwithcaffeine-hub-weu'
param azurePrivateDnsZones = [
  '/subscriptions/b67e1026-b589-41e2-b41f-73f8803f71a0/resourceGroups/rg-builtwithcaffeine-hub-weu/providers/Microsoft.Network/privateDnsZones/internal.bwc.cloud'
]

//
// Key Vault ACME Values
var subscriptionId = 'b67e1026-b589-41e2-b41f-73f8803f71a0'

//@description('ACME Azure Public DNS Subscription ID')
param acmeAzurePublicDnsSubscriptionId = subscriptionId

//@description('ACME Azure Private DNS Subscription ID')
param acmeAzurePrivateDnsSubscriptionId = subscriptionId

//@description('ACME Bot Renew Before Expiry')
param acmeBotRenewBeforeExpiry = 30

//@description('ACME Endpoint')
param acmeEndpoint = 'https://acme-v02.api.letsencrypt.org/directory'

//@description('Azure Environment')
param acmeEnvironment = 'AzureCloud'

//@description('ACME Contacts Email Address')
param acmeContacts = 'alerts@builtwithcaffeine.cloud'

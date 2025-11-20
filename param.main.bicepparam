using './main.bicep'

// Default Parameters
param customerName = 'bwc'
param environmentType = 'dev'
param location= 'westeurope'
param locationShortCode = 'weu'
param deployedBy = ''

//
// Azure Existing Resource
param sharedResourceGroupName = 'rg-builtwithcaffeine-hub-weu'
param sharedVirtualNetworkName = 'vnet-bwc-shared-hub-prod-weu'

//
// Azure Key Vault
param createWithKeyVault = true
param existingKeyVaultResourceGroup = ''
param existingKeyVaultName = ''

// Azure Network
param enableCreateVirtualNetwork = true
param virtualNetworkName = 'vnet-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param virtualNetworkAddressPrefix = '10.0.0.0/24'
param virtualNetworkSubnetShared = '10.0.0.0/28'
param virtualNetworkSubnetAppService = '10.0.0.16/28'
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

//@description('ACME Endpoint')
param acmeEndpoint = 'https://acme-v02.api.letsencrypt.org/directory'

//@description('Azure Environment')
param acmeEnvironment = 'AzureCloud'

//@description('ACME Key Vault URL Base')
var acmeKeyVaultName = 'kv-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param acmeKeyVaultUrlBase = 'https://${acmeKeyVaultName}.vault.azure.net/'

//@description('ACME Contacts Email Address')
param acmeContacts = 'alerts@builtwithcaffeine.cloud'

//@description('Key Vault ACME Package URL')
param acmeKvACMEPackage = 'https://stacmebotprod.blob.core.windows.net/keyvault-acmebot/v4/latest.zip'

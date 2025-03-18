using './main.bicep'

// Default Values

param subscriptionId = ''
param spAppId = ''
param spAuthSecret = ''
param userId = ''
param deployedBy = ''
param environmentType = 'dev'
param location = ''
param locationShortCode = ''

// Enable Private End Point Configuration and Virtual Network Configuration
param enablePrivateEndPoint = false

//
var customerName = 'bwc'

// Service Principal Name
param spName = 'sp-${customerName}-kvacme-letsencrypt-${environmentType}'

// Resource Names
param resourceGroupName = 'rg-x-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param virtualNetworkName = 'vnet-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param managedIdentityName = 'id-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param keyVaultName = 'kv-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param storageAccountName = 'st${customerName}kvacme${locationShortCode}'
param logAnalyticsWorkspaceName = 'log-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param appInsightsName = 'appi-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param appServicePlanName = 'asp-${customerName}-kvacme-${environmentType}-${locationShortCode}'
param functionAppName = 'func-${customerName}-kvacme-${environmentType}-${locationShortCode}'

// Network Parameters
param virtualNetworkCidr = '192.168.0.0/24'
param virtualNetworkSubnet = '192.168.0.0/24'

// Key Vault ACME Parameters
param acmeMailAddress = 'alerts@builtwithcaffeine.cloud'
param acmeEndPoint = 'https://acme-v02.api.letsencrypt.org/'


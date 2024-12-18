<#
.SYNOPSIS
Deploys Azure resources using a Bicep template.

.DESCRIPTION
This script automates the deployment of Azure resources using a Bicep template. It requires Azure CLI to be installed and authenticated. The script sets the Azure subscription, generates a unique deployment GUID, and deploys the Bicep template with specified parameters. It also assigns necessary roles and policies to the deployed resources.

.PARAMETER subscriptionId
The Azure subscription ID where the resources will be deployed.

.PARAMETER location
The Azure region where the resources will be deployed.

.PARAMETER environmentType
The environment type for the deployment. Valid values are 'dev', 'acc', and 'prod'.

.PARAMETER deploy
A switch parameter to trigger the deployment of the Bicep template.

.NOTES
- Ensure Azure CLI is installed and authenticated before running this script.
- The script loads additional PowerShell scripts from the 'PowerShell' folder.
- The script generates a unique deployment GUID for each deployment.
- The script assigns necessary roles and policies to the deployed resources.

- Author
Simon Lee
Twitter: https://twitter.com/smoon_lee
Blog: https://blog.builtwithcaffeine.cloud
GitHub (Personal): https://github.com/smoonlee
GitHub (BuiltWithCaffeine): https://github.com/builtwithcaffeine

.EXAMPLE
.\deployNow.ps1 -subscriptionId "your-subscription-id" -location "westeurope" -environmentType "dev" -deploy

This example deploys resources to the 'westeurope' region in the 'dev' environment type using the specified subscription ID.

#>

param (
    [parameter(Mandatory = $true)]
    [string] $subscriptionId,
    [parameter(Mandatory = $true)]
    [string] $location,
    [parameter(Mandatory = $true)]
    [ValidateSet('dev', 'acc', 'prod')]
    [string] $environmentType,
    [switch] $deploy
)

# Azure Location ShortCode Switch
switch ($location) {
    'eastus' { $locationShortCode = 'eus' }
    'eastus2' { $locationShortCode = 'eus2' }
    'westus' { $locationShortCode = 'wus' }
    'westus2' { $locationShortCode = 'wus2' }
    'northcentralus' { $locationShortCode = 'ncus' }
    'southcentralus' { $locationShortCode = 'scus' }
    'centralus' { $locationShortCode = 'cus' }
    'canadacentral' { $locationShortCode = 'cc' }
    'canadaeast' { $locationShortCode = 'ce' }
    'brazilsouth' { $locationShortCode = 'bs' }
    'northeurope' { $locationShortCode = 'neu' }
    'westeurope' { $locationShortCode = 'weu' }
    'uksouth' { $locationShortCode = 'uks' }
    'ukwest' { $locationShortCode = 'ukw' }
    'francecentral' { $locationShortCode = 'frc' }
    'francesouth' { $locationShortCode = 'frs' }
    'germanywestcentral' { $locationShortCode = 'gwc' }
    'germanynorth' { $locationShortCode = 'gn' }
    'switzerlandnorth' { $locationShortCode = 'chn' }
    'switzerlandwest' { $locationShortCode = 'chw' }
    'norwayeast' { $locationShortCode = 'noe' }
    'norwaywest' { $locationShortCode = 'now' }
    'eastasia' { $locationShortCode = 'eas' }
    'southeastasia' { $locationShortCode = 'seas' }
    'japaneast' { $locationShortCode = 'jpe' }
    'japanwest' { $locationShortCode = 'jpw' }
    'australiaeast' { $locationShortCode = 'ae' }
    'australiasoutheast' { $locationShortCode = 'ase' }
    'centralindia' { $locationShortCode = 'ci' }
    'southindia' { $locationShortCode = 'si' }
    'westindia' { $locationShortCode = 'wi' }
    'koreacentral' { $locationShortCode = 'kc' }
    'koreasouth' { $locationShortCode = 'ks' }
    'uaenorth' { $locationShortCode = 'uaen' }
    'uaecentral' { $locationShortCode = 'uaec' }
    'southafricanorth' { $locationShortCode = 'san' }
    'southafricawest' { $locationShortCode = 'saw' }
    default { $locationShortCode = $location }
}

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI (az) is not installed. Please install it from https://aka.ms/azure-cli."
    exit 1
}

# Load all the PowerShell scripts in the PowerShell folder
$path = "$PSScriptRoot\PowerShell\"
Get-ChildItem -Path $path -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Generate a unique deployment GUID
$deployGuid = (New-Guid).Guid

# Authenticate to Azure
Write-Output "Logging in to Azure..."
az login --only-show-errors --output none

# Set the subscription
Write-Output "Setting the subscription to $subscriptionId..."
az account set --subscription $subscriptionId

# Azure User Account Guid
$userPrincipalName = az ad signed-in-user show --query 'userPrincipalName' -o 'tsv'
$userId = az ad signed-in-user show --query 'id' -o 'tsv'

# # Clear Key Vaults
# Write-Output "Purging Deleted Key Vaults..."
# $deletedVaults = az keyvault list-deleted --query "[].{name:name,location:properties.location}" -o json | ConvertFrom-Json
# foreach ($vault in $deletedVaults) {
#     az keyvault purge --name $vault.name --location $vault.location
#     Write-Host "Purged Key Vault: $($vault.name)"
# }

# Key Vault ACME Parameters
$kvacmeparams = @{
    spName                    = "sp-kvacme-letsencrypt-$environmentType"
    funcName                  = "func-kvacme-$environmentType-$locationShortCode"
    entraIdGroup              = "sec-kvacme-funcapp-portal-$environmentType"

    virtualNetworkCidr        = "192.168.0.0/24"
    virtualNetworkSubnet      = "192.168.0.0/24"

    acmeMailAddress           = "alerts@builtwithcaffeine.cloud"
    acmeEndPoint              = "https://acme-v02.api.letsencrypt.org/"

    resourceGroupName         = "rg-kvacme-$environmentType-$locationShortCode"
    virtualNetworkName        = "vnet-kvacme-$environmentType-$locationShortCode"
    managedIdentityName       = "id-kvacme-$environmentType-$locationShortCode"
    keyVaultName              = "kv-kvacme-$environmentType-$locationShortCode"
    storageAccountName        = "stgkvacme$locationShortCode"
    logAnalyticsWorkspaceName = "log-kvacme-$environmentType-$locationShortCode"
    appInsightsName           = "appi-kvacme-$environmentType-$locationShortCode"
    appServicePlanName        = "asp-kvacme-$environmentType-$locationShortCode"
    functionAppName           = "func-kvacme-$environmentType-$locationShortCode"
}

# Create Service Principal
$spApp = New-EntraIdServicePrincipal -environmentType $environmentType -spName $kvacmeparams.spName  -funcName $kvacmeparams.funcName

# Deploy Bicep Template
if ($deploy) {
    $deployStartTime = Get-Date -Format 'HH:mm:ss'

    # Deploy Bicep Template
    $azDeployGuidLink = "`e]8;;https://portal.azure.com/#view/HubsExtension/DeploymentDetailsBlade/~/overview/id/%2Fsubscriptions%2F$subscriptionId%2Fproviders%2FMicrosoft.Resources%2Fdeployments%2F$deployGuid`e\$deployGuid`e]8;;`e\"
    Write-Output `r "> Deployment [$azDeployGuidLink] Started at $deployStartTime" `r

    az deployment sub create `
        --name $deployGuid `
        --location $location `
        --template-file ".\main.bicep" `
        --parameters `
        deployedBy=$userPrincipalName `
        userId=$userId `
        environmentType=$environmentType `
        spAppId=$($spApp["appId"]) `
        spAuthSecret=$($spApp["appSecret"]) `
        location=$location `
        subscriptionId=$subscriptionId `
        virtualNetworkCidr=$($kvacmeparams.virtualNetworkCidr) `
        virtualNetworkSubnet=$($kvacmeparams.virtualNetworkSubnet) `
        acmeMailAddress=$($kvacmeparams.acmeMailAddress) `
        acmeEndPoint=$($kvacmeparams.acmeEndPoint) `
        resourceGroupName=$($kvacmeparams.resourceGroupName) `
        virtualNetworkName=$($kvacmeparams.virtualNetworkName) `
        managedIdentityName=$($kvacmeparams.managedIdentityName) `
        keyVaultName=$($kvacmeparams.keyVaultName) `
        storageAccountName=$($kvacmeparams.storageAccountName) `
        logAnalyticsWorkspaceName=$($kvacmeparams.logAnalyticsWorkspaceName) `
        appInsightsName=$($kvacmeparams.appInsightsName) `
        appServicePlanName=$($kvacmeparams.appServicePlanName) `
        functionAppName=$($kvacmeparams.functionAppName) `
        --confirm-with-what-if `
        --output none

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Deployment failed. Stopping script."
        exit 1
    }

    # Get the Function App System Assigned Identity Id
    $funcSystemIdentity = az deployment sub show -n $deployGuid --query 'properties.outputs.systemAssignedIdentityId.value' -o 'tsv'
    $keyVaultName = az deployment sub show -n $deployGuid --query 'properties.outputs.keyVaultName.value' -o 'tsv'

    # # Add the Function App System Assigned Identity to Key Vault Access Policies
    Write-Output "Adding Function App System Assigned Identity to Key Vault Access Policies..."

    az keyvault set-policy `
        --name $keyVaultName  `
        --object-id $funcSystemIdentity `
        --key-permissions get list create update delete recover backup restore `
        --secret-permissions get list set delete recover backup restore `
        --certificate-permissions get list create update delete recover backup restore `
        --output none

    # Assign DNS Zone Contributor role to the Service Principal
    Write-Output `r "Assigning DNS Zone Contributor role to Service Principal..."
    az role assignment create `
        --assignee $funcSystemIdentity `
        --role "DNS Zone Contributor" `
        --scope "/subscriptions/$subscriptionId" `
        --output none

    # Assign Private DNS Zone Contributor role to the Service Principal
    Write-Output `r "Assigning Private DNS Zone Contributor role to Service Principal..."
    az role assignment create `
        --assignee $funcSystemIdentity `
        --role "Private DNS Zone Contributor" `
        --scope "/subscriptions/$subscriptionId" `
        --output none

    $deployEndTime = Get-Date -Format 'HH:mm:ss'
    $timeDifference = New-TimeSpan -Start $deployStartTime -End $deployEndTime ; $deploymentDuration = "{0:hh\:mm\:ss}" -f $timeDifference
    Write-Output `r "> Deployment [iac-bicep-$deployGuid] Started at $deployEndTime - Deployment Duration: $deploymentDuration"
}
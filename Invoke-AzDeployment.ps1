<#
.SYNOPSIS
    This script deploys Azure resources using Bicep templates and Azure CLI.

.DESCRIPTION
    The script performs the following tasks:
    - Validates and sets parameters for deployment.
    - Checks and updates Azure CLI and Bicep CLI versions.
    - Authenticates with Azure using either user or service principal credentials.
    - Retrieves Azure identity information.
    - Generates a random password.
    - Maps Azure location short codes.
    - Creates a deployment GUID for tracking.
    - Deploys the Bicep template to the specified target scope.

.PARAMETER targetScope
    The target scope for the deployment. Valid values are 'tenant', 'mgmt', and 'sub'.

.PARAMETER subscriptionId
    The Azure Subscription ID. Must be a 36-character string.

.PARAMETER environmentType
    The environment type for the deployment. Valid values are 'dev', 'acc', and 'prod'.

.PARAMETER location
    The Azure location for the deployment. Must be one of the specified Azure regions.

.PARAMETER deploy
    Switch to execute the infrastructure deployment.

.PARAMETER servicePrincipalAuthentication
    Switch to use service principal authentication.

.PARAMETER spAuthCredentialFile
    Path to the service principal authentication file.

    JSON File Example:

    {
        "spAppId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        "spAppSecret": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        "spTenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    }

.FUNCTION Get-AzCliVersion
    Checks if Azure CLI is installed and updates it if a new version is available.

.FUNCTION Get-BicepVersion
    Checks if Bicep CLI is installed and updates it if a new version is available.

.FUNCTION Get-AzIdentity
    Retrieves Azure identity information and role assignments.

.FUNCTION New-RandomPassword
    Generates a random password with a specified length and number of non-alphanumeric characters.

.NOTES
    Author: Simon Lee (BuiltWithCaffeine)
    Date: 2025-03-17
    Version: 2.0

.EXAMPLE
    .\Invoke-AzDeployment.ps1 -targetScope 'sub' -subscriptionId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -environmentType 'dev' -location 'westeurope' -deploy

.EXAMPLE
    .\Invoke-AzDeployment.ps1 -targetScope 'sub' -subscriptionId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -environmentType 'dev' -location 'westeurope' -deploy -servicePrincipalAuthentication -spAuthCredentialFile 'C:\auth\spApp.txt'

#>
param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Deployment Guid is required")]
    [validateSet('tenant', 'mgmt', 'sub')] [string] $targetScope,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Azure Subscription Id is required")]
    [ValidateLength(36, 36)] [string] $subscriptionId,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "Environment Type is required")]
    [validateSet('dev', 'acc', 'prod')][string] $environmentType,

    [Parameter(Mandatory = $true, Position = 3, HelpMessage = "Azure Location is required")]
    [validateSet("eastus", "eastus2", "eastus3", "westus", "westus2", "westus3", "centralus", "northcentralus",
        "southcentralus", "westcentralus", "canadacentral", "canadaeast", "brazilsouth", "brazilseast",
        "northeurope", "westeurope", "swedencentral", "swedensouth", "francecentral", "francesouth",
        "germanywestcentral", "germanynorth", "switzerlandnorth", "switzerlandwest", "norwayeast", "norwaywest",
        "polandcentral", "spaincentral", "qatarcentral", "uaenorth", "uaecentral", "southafricanorth",
        "southafricawest", "southafricaeast", "eastasia", "southeastasia", "japaneast", "japanwest",
        "australiaeast", "australiasoutheast", "australiacentral", "australiacentral2", "centralindia",
        "southindia", "westindia", "koreacentral", "koreasouth", "chinaeast3", "chinanorth3", "indonesiacentral",
        "malaysiawest", "newzealandnorth", "taiwannorth", "israelcentral", "mexicocentral", "greececentral",
        "finlandcentral", "austriaeast", "belgiumcentral", "denmarkeast", "norwaysouth", "italynorth",
        "usgovvirginia", "usgovarizona", "usgovtexas", "usgoviowa")]
    [string] $location,

    [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Execute Infrastructure Deployment")]
    [switch] $deploy,

    [Parameter(Mandatory = $false, Position = 5, HelpMessage = "Execute Infrastructure Deployment")]
    [switch] $servicePrincipalAuthentication,

    [Parameter(Mandatory = $false, Position = 6, HelpMessage = "Service Principal Authentication File")]
    [String] $spAuthCredentialFile
)

#
# PowerShell Functions
#

# Load External PowerShell Functions
$path = "$PSScriptRoot\PowerShell\"
Get-ChildItem -Path $path -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

function Get-AzCliVersion {

    # Check if Azure CLI is installed
    if (-not (Get-Command -Name 'az' -ErrorAction SilentlyContinue)) {
        Write-Warning "Azure CLI (az) is not installed. Please install it from https://aka.ms/azure-cli."
        exit 1
    }

    # Verbose Output
    Write-Output `r "Checking for Azure CLI..."

    # Get the installed version of Azure CLI
    $installedVersion = az version --output json | ConvertFrom-Json | Select-Object -ExpandProperty azure-cli

    if (-not $installedVersion) {
        Write-Output "Azure CLI is not installed or version couldn't be determined."
        return
    }

    Write-Output "Installed Azure CLI version: $installedVersion"

    # Get the latest release version from GitHub
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Azure/azure-cli/releases/latest"

    if (-not $latestRelease) {
        Write-Output "Unable to fetch the latest release."
        return
    }

    $latestVersion = $latestRelease.tag_name.TrimStart('azure-cli-')  # GitHub version starts with 'azure-cli-'

    # Compare versions
    if ($installedVersion -eq $latestVersion) {
        Write-Output "Azure CLI is up to date."
    }
    else {
        Write-Output "A new version of Azure CLI is available. Latest Release is: $latestVersion."
        # Prompt for user input (Yes/No)
        $response = Read-Host "Do you want to update? (Y/N)"

        if ($response -match '^[Yy]$') {
            Write-Output "" # Required for Verbose Spacing
            az upgrade
            Write-Output "Azure CLI has been updated to version $latestVersion."
        }
        elseif ($response -match '^[Nn]$') {
            Write-Output "Update canceled."
        }
        else {
            Write-Output "Invalid response. Please answer with Y or N."
        }
    }
}

# Function - Get-BicepVersion
function Get-BicepVersion {

    #
    Write-Output `r "Checking for Bicep CLI..."

    # Get the installed version of Bicep
    $installedVersion = az bicep version --only-show-errors | Select-String -Pattern 'Bicep CLI version (\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }

    if (-not $installedVersion) {
        Write-Output "Bicep CLI is not installed or version couldn't be determined."
        return
    }

    Write-Output "Installed Bicep version: $installedVersion"

    # Get the latest release version from GitHub
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Azure/bicep/releases/latest"

    if (-not $latestRelease) {
        Write-Output "Unable to fetch the latest release."
        return
    }

    $latestVersion = $latestRelease.tag_name.TrimStart('v')  # GitHub version starts with 'v'

    # Compare versions
    if ($installedVersion -eq $latestVersion) {
        Write-Output "Bicep is up to date."
    }
    else {
        Write-Output "A new version of Bicep is available. Latest Release is: $latestVersion."
        # Prompt for user input (Yes/No)
        $response = Read-Host "Do you want to update? (Y/N)"

        if ($response -match '^[Yy]$') {
            Write-Output "" # Required for Verbose Spacing
            az bicep upgrade
            Write-Output "Bicep has been updated to version $latestVersion."
        }
        elseif ($response -match '^[Nn]$') {
            Write-Output "Update canceled."
        }
        else {
            Write-Output "Invalid response. Please answer with Y or N."
        }
    }
}

# Get Azure User/Service Principal Identity
function Get-AzIdentity {
    # Get Identity Type
    $azIdentity = az account show | ConvertFrom-Json

    if ($azIdentity.user.type -eq 'servicePrincipal') {
        $spDisplayName = az ad sp show --id (az account show --query 'user.name' -o 'tsv') --query 'displayName' -o 'tsv'
    }

    if ($azIdentity.user.type -eq 'user') {
        $azUserAccountName = az account show --query 'user.name' -o 'tsv'
    }

    Write-Host "Azure Identity Information:"
    Write-Host "Identity Type.........: $($azIdentity.user.type)"
    if ($azIdentity.user.type -eq 'servicePrincipal') {
        Write-Host "Service Principal.....: $spDisplayName"
        $azIdentityName = $spDisplayName
    }

    if ($azIdentity.user.type -eq 'user') {
        Write-Host "User Account Email....: $azUserAccountName"
        $azIdentityName = $azUserAccountName
    }

    # Get Role Base Assignments
    $rbacAssignment = az role assignment list --assignee $azIdentity.user.name --output json | ConvertFrom-Json
    Write-Host "RBAC Assignment.......: $($rbacAssignment.RoleDefinitionName)"

    # Return Azure Identity Value
    return $azIdentityName
}

# Generate Random Password
function New-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length,
        [int] $amountOfNonAlphanumeric = 2
    )

    $nonAlphaNumericChars = '!@$#%^&*()_-+=[{]};:<>|./?'
    $nonAlphaNumericPart = -join ((Get-Random -Count $amountOfNonAlphanumeric -InputObject $nonAlphaNumericChars.ToCharArray()))

    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $alphabetPart = -join ((Get-Random -Count ($length - $amountOfNonAlphanumeric) -InputObject $alphabet.ToCharArray()))

    $password = ($alphabetPart + $nonAlphaNumericPart).ToCharArray() | Sort-Object { Get-Random }

    return -join $password
}

# Get Bicep Param Values
function Get-BicepParamValues {
    Param (
        [string] $paramFilePath
    )

    # Get Content
    $bicepParamContent = Get-Content -Path $paramFilePath

    # Replace ${customerName} with the actual value
    $customerName = ($bicepParamContent | Select-String -Pattern 'var customerName' | ForEach-Object { ($_ -split '=')[1].Trim() }).Trim("'")
    $bicepParamContent = $bicepParamContent -replace '\${customerName}', $customerName -replace '\${environmentType}', $environmentType -replace '\${locationShortCode}', $locationShortCodeMap.$location

    # Parse and return param spName, param functionAppName, and param customerName
    return @{
        spName       = ($bicepParamContent | Select-String -Pattern 'param spName' | ForEach-Object { ($_ -split '=')[1].Trim() }).Trim("'")
        funcName     = ($bicepParamContent | Select-String -Pattern 'param functionAppName' | ForEach-Object { ($_ -split '=')[1].Trim() }).Trim("'")
    }
}

# PowerShell Location Shortcode Map
$locationShortCodeMap = @{
    "eastus"             = "eus"
    "eastus2"            = "eus2"
    "eastus3"            = "eus3"
    "westus"             = "wus"
    "westus2"            = "wus2"
    "westus3"            = "wus3"
    "northcentralus"     = "ncus"
    "southcentralus"     = "scus"
    "centralus"          = "cus"
    "westcentralus"      = "wcus"
    "canadacentral"      = "canc"
    "canadaeast"         = "cane"
    "brazilsouth"        = "brs"
    "brazilseast"        = "bre"
    "northeurope"        = "neu"
    "westeurope"         = "weu"
    "swedencentral"      = "sec"
    "swedensouth"        = "ses"
    "francecentral"      = "frc"
    "francesouth"        = "frs"
    "germanywestcentral" = "gwc"
    "germanynorth"       = "gn"
    "switzerlandnorth"   = "chn"
    "switzerlandwest"    = "chw"
    "norwayeast"         = "noe"
    "norwaywest"         = "now"
    "polandcentral"      = "plc"
    "spaincentral"       = "spc"
    "qatarcentral"       = "qtc"
    "uaenorth"           = "uan"
    "uaecentral"         = "uac"
    "southafricanorth"   = "san"
    "southafricawest"    = "saw"
    "southafricaeast"    = "sae"
    "eastasia"           = "ea"
    "southeastasia"      = "sea"
    "japaneast"          = "jpe"
    "japanwest"          = "jpw"
    "australiaeast"      = "aue"
    "australiasoutheast" = "ause"
    "australiacentral"   = "auc"
    "australiacentral2"  = "auc2"
    "centralindia"       = "cin"
    "southindia"         = "sin"
    "westindia"          = "win"
    "koreacentral"       = "korc"
    "koreasouth"         = "kors"
    "chinaeast3"         = "ce3"
    "chinanorth3"        = "cn3"
    "indonesiacentral"   = "idc"
    "malaysiawest"       = "myw"
    "newzealandnorth"    = "nzn"
    "taiwannorth"        = "twn"
    "israelcentral"      = "ilc"
    "mexicocentral"      = "mxc"
    "greececentral"      = "grc"
    "finlandcentral"     = "fic"
    "austriaeast"        = "ate"
    "belgiumcentral"     = "bec"
    "denmarkeast"        = "dke"
    "norwaysouth"        = "nos"
    "italynorth"         = "itn"
    "usgovvirginia"      = "usgv"
    "usgovarizona"       = "usga"
    "usgovtexas"         = "usgt"
    "usgoviowa"          = "usgi"
}

# Create Deployment Guid for Tracking in Azure
$deployGuid = (New-Guid).Guid

# Check Azure CLI
Get-AzCliVersion

# Check Azure Bicep Version
Get-BicepVersion

# Service Principal Authentication
if ($servicePrincipalAuthentication) {
    if (-not $spAuthCredentialFile) {
        Write-Output `r "Enter Service Principal Details:"
        $spAppId = Read-Host "Service Principal App Id"
        $spAppSecret = Read-Host "Service Principal App Secret" -AsSecureString
        $spTenantId = Read-Host "Service Principal Tenant Id"
    }
    else {
        try {
            $spAuthCredential = Get-Content -Path $spAuthCredentialFile | ConvertFrom-Json
            $spAppId = $spAuthCredential.spAppId
            $spAppSecret = $spAuthCredential.spAppSecret
            $spTenantId = $spAuthCredential.spTenantId
        }
        catch {
            Write-Error "Failed to parse Service Principal authentication file: $_"
            exit 1
        }
    }

    # Authenticate using Service Principal
    Write-Output `r "Authenticating with Azure - Service Principal..." `r
    az login --service-principal -u $spAppId -p $spAppSecret --tenant $spTenantId --output none

    # Validate Role Assignments
    $spRoleAssignments = az role assignment list --assignee $spAppId --output json 2>$null | ConvertFrom-Json
    if (-not $spRoleAssignments) {
        Write-Warning "Service Principal lacks role assignments. Assign appropriate roles before proceeding."
        exit 1
    }
}

if (!$servicePrincipalAuthentication) {
    # Authenticate using Azure CLI
    Write-Output `r "Authenticating with Azure - User Authentication..."
    az login --output none --only-show-errors
}

# Get Azure Identity, Required for Deployment Tags (DeployedBy:)
$azIdentityName = Get-AzIdentity
$azIdentityGuid = az ad signed-in-user show --query 'id' --output 'tsv'

# Change Azure Subscription
Write-Output `r "Updating Azure Subscription context to $subscriptionId"
az account set --subscription $subscriptionId --output none

# Get Bicep Parameters
$params = Get-BicepParamValues -paramFilePath ./main.bicepparam
$spApp = New-EntraIdServicePrincipal -environmentType $environmentType -spName $params.spName  -funcName $params.funcName

Write-Output `r "Pre Flight Variable Validation:"
Write-Output "Deployment Guid......: $deployGuid"
Write-Output "Location.............: $location"
Write-Output "Location Short Code..: $($locationShortCodeMap.$location)"
Write-Output "Environment..........: $environmentType"

if ($deploy) {
    $deployStartTime = Get-Date -Format 'HH:mm:ss'

    # Deploy Bicep Template
    $azDeployGuidLink = "`e]8;;https://portal.azure.com/#view/HubsExtension/DeploymentDetailsBlade/~/overview/id/%2Fsubscriptions%2F$subscriptionId%2Fproviders%2FMicrosoft.Resources%2Fdeployments%2Fiac-$deployGuid`e\iac-$deployGuid`e]8;;`e\"
    Write-Output `r "> Deployment [$azDeployGuidLink] Started at $deployStartTime"

    az deployment $targetScope create `
        --name iac-$deployGuid `
        --location $location `
        --template-file ./main.bicep `
        --parameters ./main.bicepparam `
        --parameters `
        location=$location `
        locationShortCode=$($locationShortCodeMap.$location) `
        environmentType=$environmentType `
        deployedBy=$azIdentityName `
        subscriptionId=$subscriptionId `
        userId=$azIdentityGuid `
        spAppId=$($spApp["appId"]) `
        spAuthSecret=$($spApp["appSecret"]) `
        --confirm-with-what-if `
        --output none

    $deployEndTime = Get-Date -Format 'HH:mm:ss'
    $timeDifference = New-TimeSpan -Start $deployStartTime -End $deployEndTime ; $deploymentDuration = "{0:hh\:mm\:ss}" -f $timeDifference
    Write-Output `r "> Deployment [$azDeployGuidLink] Started at $deployEndTime - Deployment Duration: $deploymentDuration"
}
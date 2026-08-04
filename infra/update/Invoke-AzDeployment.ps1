<#
.SYNOPSIS
  Wrapper script for deploying the Acmebot update template at resource group scope.

.DESCRIPTION
  This script validates environment prerequisites, authenticates to Azure, discovers the existing Function App resource group,
  and deploys the update Bicep template using Azure CLI.

.PARAMETER subscriptionId
  Azure Subscription Id containing the existing Acmebot Function App.

.PARAMETER functionAppName
  Existing Acmebot Function App name.

.PARAMETER location
  Optional Azure region/location for the deployment record. If omitted, the Function App location is used.

.PARAMETER deploy
    If specified, executes the deployment. Otherwise, only validates and performs pre-flight checks.

.EXAMPLE
  .\Invoke-AzDeployment.ps1 -subscriptionId <subId> -functionAppName <app-name> -location westeurope -deploy

.NOTES
    Author: BuiltWithCaffeine
    Requires: PowerShell 7+, Azure CLI, Bicep CLI
    Script Version: 2.0
#>

# Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess)]
param (
  [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Azure Subscription Id containing the existing Acmebot Function App")]
  [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')] [string] $subscriptionId,

  [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Existing Acmebot Function App name")]
  [string] $functionAppName,

  [Parameter(Mandatory = $false, Position = 2, HelpMessage = "Optional Azure location for the deployment record")]
  [string] $location,

  [Parameter(Mandatory = $false, Position = 3, HelpMessage = "Execute Infrastructure Deployment")]
  [switch] $deploy,

  [Parameter(Mandatory = $false, Position = 4, HelpMessage = "Optional Bicep template file path. Defaults to ./main.bicep")]
  [string] $templateFile = './main.bicep'
)

# Enforce strict mode and stop on errors
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $templateFile -PathType Leaf)) {
  throw "Template file '$templateFile' was not found."
}

#
# PowerShell Functions
#

function Get-AzCliVersion {

  # Check if Azure CLI is installed
  if (-not (Get-Command -Name 'az' -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed. Please install it from https://aka.ms/azure-cli."
  }

  Write-Host "Checking for Azure CLI"

  # Get the installed version of Azure CLI
  $azVersionJson = az version --output json 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to determine Azure CLI version."
    return
  }
  $installedVersion = ($azVersionJson | ConvertFrom-Json).'azure-cli'

  if (-not $installedVersion) {
    Write-Warning "Azure CLI version could not be determined."
    return
  }

  Write-Host "Installed Azure CLI version: $installedVersion"

  # Get the latest release version from GitHub
  try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Azure/azure-cli/releases/latest"
    $latestVersion = $latestRelease.tag_name.TrimStart('azure-cli-')
  } catch {
    Write-Warning "Unable to fetch the latest release. Ensure you have internet connectivity."
    return
  }

  # Compare versions using semantic versioning
  if ([version]$installedVersion -ge [version]$latestVersion) {
    Write-Host "Azure CLI is up to date."
  } else {
    Write-Host "A new version of Azure CLI is available. Latest Release is: $latestVersion."

    if (-not [Environment]::UserInteractive) {
      Write-Warning "Non-interactive session detected. Skipping Azure CLI update prompt."
      return
    }

    $response = Read-Host "Do you want to update? (Y/N)"

    switch ($response.ToUpper()) {
      "Y" {
        if ($IsWindows -and (Get-Command -Name 'winget' -ErrorAction SilentlyContinue)) {
          Write-Host "Updating Azure CLI via WinGet, please wait"
          winget upgrade --id Microsoft.AzureCLI --accept-source-agreements --accept-package-agreements 2>&1 | Out-Host
        } else {
          Write-Host "Updating Azure CLI via az upgrade, please wait"
          az upgrade --yes 2>&1 | Out-Host
        }
        if ($LASTEXITCODE -ne 0) {
          Write-Warning "Failed to update Azure CLI. Please try updating manually."
        } else {
          Write-Host "Azure CLI has been updated to version $latestVersion."
        }
      }
      "N" {
        Write-Host "Update canceled."
      }
      default {
        Write-Host "Invalid response. Please answer with Y or N."
      }
    }
  }
}

# Function - Get-BicepVersion
function Get-BicepVersion {

  Write-Host "Checking for Bicep CLI"

  # Check if Bicep CLI is installed
  $bicepOutput = az bicep version --only-show-errors 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Bicep CLI is not installed. Please install it using 'az bicep install'."
    return
  }
  $installedVersion = $bicepOutput | Select-String -Pattern 'Bicep CLI version (\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }

  if (-not $installedVersion) {
    Write-Warning "Bicep CLI version could not be determined."
    return
  }

  Write-Host "Installed Bicep version: $installedVersion"

  # Get the latest release version from GitHub
  try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/Azure/bicep/releases/latest"
    $latestVersion = $latestRelease.tag_name.TrimStart('v')
  } catch {
    Write-Warning "Unable to fetch the latest release. Ensure you have internet connectivity."
    return
  }

  # Compare versions using semantic versioning
  if ([version]$installedVersion -ge [version]$latestVersion) {
    Write-Host "Bicep CLI is up to date."
  } else {
    Write-Host "A new version of Bicep CLI is available. Latest Release: $latestVersion."

    if (-not [Environment]::UserInteractive) {
      Write-Warning "Non-interactive session detected. Skipping Bicep CLI update prompt."
      return
    }

    $response = Read-Host "Do you want to update? (Y/N)"

    switch ($response.ToUpper()) {
      "Y" {
        Write-Host "Updating Bicep CLI, please wait"
        az bicep upgrade 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) {
          Write-Warning "Failed to update Bicep CLI. Please try updating manually."
        } else {
          Write-Host "Bicep CLI has been updated to version $latestVersion."
        }
      }
      "N" {
        Write-Host "Update canceled."
      }
      default {
        Write-Host "Invalid response. Please answer with Y or N."
      }
    }
  }
}

function Get-FunctionAppContext {
  param (
    [Parameter(Mandatory = $true)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $FunctionAppName
  )

  try {
    $functionAppJson = az resource list --subscription $SubscriptionId --resource-type 'Microsoft.Web/sites' --name $FunctionAppName --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to locate Function App '$FunctionAppName' in subscription '$SubscriptionId'."
    }

    $functionApps = @($functionAppJson | ConvertFrom-Json)
    $functionApp = $functionApps | Select-Object -First 1

    if (-not $functionApp) {
      throw "Function App '$FunctionAppName' was not found in subscription '$SubscriptionId'."
    }

    if (-not $functionApp.resourceGroup) {
      throw "Function App '$FunctionAppName' did not return a resource group."
    }

    [pscustomobject]@{
      ResourceGroupName = $functionApp.resourceGroup
      Location = $functionApp.location
      ResourceId = $functionApp.id
    }
  } catch {
    throw "Failed to resolve Function App context for '$FunctionAppName': $_"
  }
}

# Check Azure CLI
Get-AzCliVersion

Write-Host ""

# Check Azure Bicep CLI
Get-BicepVersion

Write-Host ""

# Authenticate using Azure CLI if needed
Write-Host "Authenticating with Azure"
$azAccountJson = az account show --output json 2>&1
if ($LASTEXITCODE -ne 0) {
  az login --output none --only-show-errors
  if ($LASTEXITCODE -ne 0) { throw "Azure CLI login failed." }
}

Write-Host ""
Write-Host "Setting Azure Subscription context: $subscriptionId"
az account set --subscription $subscriptionId --output none
if ($LASTEXITCODE -ne 0) { throw "Failed to set Azure subscription context to '$subscriptionId'." }

Write-Host ""

$functionAppContext = Get-FunctionAppContext -SubscriptionId $subscriptionId -FunctionAppName $functionAppName
$resourceGroupName = $functionAppContext.ResourceGroupName
$deploymentLocation = if ($location) { $location } else { $functionAppContext.Location }

if (-not $deploymentLocation) {
  throw "Unable to determine deployment location. Pass -location or ensure the Function App location is available."
}

$deployGuid = (New-Guid).Guid
$deployName = "iac-update-$deployGuid"

Write-Host "Pre Flight Variable Validation:"
Write-Host "Deployment Guid......: $deployName"
Write-Host "Subscription Id......: $subscriptionId"
Write-Host "Function App Name....: $functionAppName"
Write-Host "Resource Group.......: $resourceGroupName"
Write-Host "Deployment Location..: $deploymentLocation"
Write-Host "Template File........: $templateFile"

if ($deploy) {
  $scopeTarget = "Resource Group '$resourceGroupName'"
  if ($PSCmdlet.ShouldProcess($scopeTarget, "Deploy Bicep template '$templateFile'")) {
    $deployStartTime = Get-Date

    Write-Host ""
    Write-Host "> Planned Infrastructure Changes:"

    $deployParams = @(
      '--name', $deployName,
      '--resource-group', $resourceGroupName,
      '--location', $deploymentLocation,
      '--template-file', $templateFile,
      '--parameters', './param.main.bicepparam',
      '--parameters', "functionAppName=$functionAppName"
    )

    az deployment group what-if @deployParams
    if ($LASTEXITCODE -ne 0) { throw "What-If validation failed for '$deployName'." }

    Write-Host ""
    $confirmDeploy = Read-Host "Proceed with deployment? (Y/N)"
    if ($confirmDeploy.ToUpper() -ne 'Y') {
      Write-Host "Deployment canceled by user."
      return
    }

    Write-Host ""
    Write-Host "> Deployment [$deployName] Started at $($deployStartTime.ToString('HH:mm:ss'))"

    az deployment group create @deployParams --output none
    if ($LASTEXITCODE -ne 0) { throw "Bicep deployment '$deployName' failed with exit code $LASTEXITCODE." }

    $deployEndTime = Get-Date
    $deploymentDuration = $deployEndTime - $deployStartTime
    Write-Host "> Deployment [$deployName] Completed at $($deployEndTime.ToString('HH:mm:ss')) - Duration: $($deploymentDuration.ToString('hh\:mm\:ss'))"
  }
}

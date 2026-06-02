#Requires -Version 7

param(
    [Parameter(Mandatory = $false)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string] $ManagementGroupId,

    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = 'rg-avm-approleassignedto-dev-001',

    [Parameter(Mandatory = $false)]
    [string] $Location = 'West Europe',

    [Parameter(Mandatory = $false)]
    [string] $RemoveDeployment,

    [Parameter(Mandatory = $false)]
    [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'

# Load functions
. (Join-Path $PSScriptRoot '..' '..' '..' 'utilities' 'tools' 'Test-TemplateWithParameterFile.ps1')

# General variables
$moduleTestFilePath = Join-Path $PSScriptRoot 'test' 'main.test.bicep'

# For Azure deployment
$deploymentName = 'test-{0}-{1}-{2}' -f (Split-Path $PSScriptRoot -Leaf), (Get-Date -Format 'yyyyMMdd-HHmmss'), (Get-Random -Maximum 9999)

if ($SubscriptionId -and (-not $ManagementGroupId)) {
    $context = Get-AzContext
    if ((-not $context) -or ($context.Subscription.Id -ne $SubscriptionId)) {
        Write-Verbose "Setting Az context to subscription [$SubscriptionId]" -Verbose
        $null = Set-AzContext -Subscription $SubscriptionId
    }
    $deploymentScope = 'subscription'
} elseif ($ManagementGroupId -and (-not $SubscriptionId)) {
    $deploymentScope = 'managementGroup'
} else {
    $deploymentScope = 'resourceGroup'
    if ($SubscriptionId) {
        $context = Get-AzContext
        if ((-not $context) -or ($context.Subscription.Id -ne $SubscriptionId)) {
            Write-Verbose "Setting Az context to subscription [$SubscriptionId]" -Verbose
            $null = Set-AzContext -Subscription $SubscriptionId
        }
    }
}

Write-Verbose "Deployment scope: [$deploymentScope]" -Verbose

# Test deployment
$deploymentInputs = @{
    DeploymentName = $deploymentName
    TemplateFilePath = $moduleTestFilePath
    Location = $Location
    Verbose = $true
}

if ($deploymentScope -eq 'managementGroup') {
    $deploymentInputs['ManagementGroupId'] = $ManagementGroupId
} elseif ($deploymentScope -eq 'subscription') {
    # No additional parameters needed for subscription scope
} else {
    $deploymentInputs['ResourceGroupName'] = $ResourceGroupName
}

if ($WhatIf) {
    $deploymentInputs['WhatIf'] = $true
}

Write-Verbose ('Invoke test with deployment name [{0}] and test file [{1}]' -f $deploymentName, $moduleTestFilePath) -Verbose

Test-TemplateWithParameterFile @deploymentInputs

if ($RemoveDeployment) {
    Write-Verbose "Removing deployment [$deploymentName]" -Verbose
    if ($deploymentScope -eq 'managementGroup') {
        Remove-AzManagementGroupDeployment -ManagementGroupId $ManagementGroupId -Name $deploymentName
    } elseif ($deploymentScope -eq 'subscription') {
        Remove-AzSubscriptionDeployment -Name $deploymentName
    } else {
        Remove-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName
    }
}

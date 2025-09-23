# Deploy Microsoft Graph Groups Module

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "parameters.example.json",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "West Europe",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Validate parameters file exists
if (-not (Test-Path $ParametersFile)) {
    Write-Error "Parameters file '$ParametersFile' not found."
    exit 1
}

Write-Host "🚀 Deploying Microsoft Graph Groups Module..." -ForegroundColor Green
Write-Host "📁 Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "📄 Parameters File: $ParametersFile" -ForegroundColor Yellow
Write-Host "🌍 Location: $Location" -ForegroundColor Yellow

try {
    # Ensure resource group exists
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "📝 Creating resource group '$ResourceGroupName'..." -ForegroundColor Yellow
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    }

    # Deploy the module
    $deploymentName = "groups-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    $deploymentParams = @{
        ResourceGroupName     = $ResourceGroupName
        TemplateFile         = "main.bicep"
        TemplateParameterFile = $ParametersFile
        Name                 = $deploymentName
        Force                = $true
    }
    
    if ($WhatIf) {
        Write-Host "🔍 Running What-If analysis..." -ForegroundColor Yellow
        $result = New-AzResourceGroupDeployment @deploymentParams -WhatIf
        Write-Host "✅ What-If analysis completed" -ForegroundColor Green
        return $result
    }
    else {
        Write-Host "🚀 Starting deployment..." -ForegroundColor Yellow
        $result = New-AzResourceGroupDeployment @deploymentParams
        
        if ($result.ProvisioningState -eq "Succeeded") {
            Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
            Write-Host "📋 Deployment Details:" -ForegroundColor Yellow
            Write-Host "  Group ID: $($result.Outputs.groupId.Value)" -ForegroundColor White
            Write-Host "  Display Name: $($result.Outputs.displayName.Value)" -ForegroundColor White
            Write-Host "  Resource ID: $($result.Outputs.resourceId.Value)" -ForegroundColor White
        }
        else {
            Write-Error "❌ Deployment failed with status: $($result.ProvisioningState)"
        }
        
        return $result
    }
}
catch {
    Write-Error "❌ Deployment failed: $($_.Exception.Message)"
    exit 1
}

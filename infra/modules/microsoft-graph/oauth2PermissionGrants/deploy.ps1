# Deploy Microsoft Graph OAuth2 Permission Grants Module

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

Write-Host "🚀 Deploying Microsoft Graph OAuth2 Permission Grants Module..." -ForegroundColor Green
Write-Host "📁 Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "📄 Parameters File: $ParametersFile" -ForegroundColor Yellow
Write-Host "🌍 Location: $Location" -ForegroundColor Yellow

try {
    # Generate deployment name
    $deploymentName = "oauth2-permission-grants-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    Write-Host "🔧 Deployment Name: $deploymentName" -ForegroundColor Yellow
    
    if ($WhatIf) {
        Write-Host "🔍 Running What-If deployment..." -ForegroundColor Blue
        
        $whatIfResult = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile "main.bicep" `
            -TemplateParameterFile $ParametersFile `
            -Name $deploymentName `
            -WhatIf
            
        Write-Host "✅ What-If deployment completed successfully!" -ForegroundColor Green
        return $whatIfResult
    }
    else {
        Write-Host "🚀 Starting deployment..." -ForegroundColor Blue
        
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile "main.bicep" `
            -TemplateParameterFile $ParametersFile `
            -Name $deploymentName `
            -Verbose
            
        Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
        Write-Host "📊 Deployment Details:" -ForegroundColor Yellow
        Write-Host "   📝 Name: $($deployment.DeploymentName)" -ForegroundColor White
        Write-Host "   🎯 State: $($deployment.ProvisioningState)" -ForegroundColor White
        Write-Host "   ⏱️  Duration: $($deployment.Duration)" -ForegroundColor White
        
        if ($deployment.Outputs) {
            Write-Host "📤 Outputs:" -ForegroundColor Yellow
            $deployment.Outputs | Format-Table -AutoSize
        }
        
        return $deployment
    }
}
catch {
    Write-Error "❌ Deployment failed: $($_.Exception.Message)"
    if ($_.Exception.InnerException) {
        Write-Error "💥 Inner Exception: $($_.Exception.InnerException.Message)"
    }
    exit 1
}

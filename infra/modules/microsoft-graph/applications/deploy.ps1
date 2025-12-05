# Microsoft Graph Application Module Deployment Script
# This script demonstrates how to deploy the module using Azure CLI

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "West Europe",
    
    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "dev",
    
    [Parameter(Mandatory = $false)]
    [string]$AppNamePrefix = "contoso"
)

# Set the Azure subscription context
Write-Host "Setting Azure subscription context..." -ForegroundColor Green
az account set --subscription $SubscriptionId

# Create resource group if it doesn't exist
Write-Host "Ensuring resource group exists..." -ForegroundColor Green
az group create --name $ResourceGroupName --location $Location

# Deploy the test template
Write-Host "Deploying Microsoft Graph applications..." -ForegroundColor Green
$deploymentName = "msgraph-app-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "./test/main.test.bicep" `
    --parameters environmentName=$EnvironmentName appNamePrefix=$AppNamePrefix `
    --name $deploymentName `
    --verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    
    # Get deployment outputs
    Write-Host "Retrieving deployment outputs..." -ForegroundColor Green
    $outputs = az deployment group show --resource-group $ResourceGroupName --name $deploymentName --query "properties.outputs" --output json | ConvertFrom-Json
    
    Write-Host "Created Applications:" -ForegroundColor Yellow
    Write-Host "- Web App: $($outputs.webApplication.value.displayName) (ID: $($outputs.webApplication.value.applicationId))" -ForegroundColor White
    Write-Host "- SPA App: $($outputs.spaApplication.value.displayName) (ID: $($outputs.spaApplication.value.applicationId))" -ForegroundColor White
    Write-Host "- API App: $($outputs.apiApplication.value.displayName) (ID: $($outputs.apiApplication.value.applicationId))" -ForegroundColor White
    Write-Host "- Mobile App: $($outputs.mobileApplication.value.displayName) (ID: $($outputs.mobileApplication.value.applicationId))" -ForegroundColor White
} else {
    Write-Error "Deployment failed. Please check the error messages above."
    exit 1
}

Write-Host "Script completed!" -ForegroundColor Green

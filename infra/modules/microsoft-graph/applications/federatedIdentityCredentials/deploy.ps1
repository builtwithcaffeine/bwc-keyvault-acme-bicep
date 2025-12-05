# Microsoft Graph Federated Identity Credentials Deployment Script
# This script deploys the module which automatically creates Azure AD applications and federated credentials

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
    [string]$OrganizationName = "contoso",
    
    [Parameter(Mandatory = $false)]
    [string]$RepositoryName = "myapp",
    
    [Parameter(Mandatory = $false)]
    [string]$AzdoOrganization = "myorg",
    
    [Parameter(Mandatory = $false)]
    [string]$AzdoProject = "myproject"
)

# Set the Azure subscription context
Write-Host "Setting Azure subscription context..." -ForegroundColor Green
az account set --subscription $SubscriptionId

# Create resource group if it doesn't exist
Write-Host "Ensuring resource group exists..." -ForegroundColor Green
az group create --name $ResourceGroupName --location $Location

# Deploy the federated identity credentials (this creates actual Azure AD resources)
Write-Host "Deploying federated identity credentials..." -ForegroundColor Green
$deploymentName = "federated-identity-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "./test/main.test.bicep" `
    --parameters environmentName=$EnvironmentName organizationName=$OrganizationName repositoryName=$RepositoryName azdoOrganization=$AzdoOrganization azdoProject=$AzdoProject `
    --name $deploymentName `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed. Please check the error messages above."
    exit 1
}

Write-Host "Deployment completed successfully!" -ForegroundColor Green

# Get deployment outputs
Write-Host "Retrieving deployment results..." -ForegroundColor Green
$outputs = $deploymentResult.properties.outputs

Write-Host "`n=== Created Resources ===" -ForegroundColor Yellow

# Display GitHub Main Branch configuration
$githubMain = $outputs.githubMainBranchConfig.value
Write-Host "`n--- GitHub Main Branch ---" -ForegroundColor Cyan
Write-Host "Application ID: $($githubMain.applicationId)" -ForegroundColor White
Write-Host "Credential Resource ID: $($githubMain.credentialResourceId)" -ForegroundColor White
Write-Host "Credential Name: $($githubMain.credentialName)" -ForegroundColor White
Write-Host "Issuer: $($githubMain.issuer)" -ForegroundColor White
Write-Host "Subject: $($githubMain.subject)" -ForegroundColor White

# Display GitHub Pull Requests configuration
$githubPR = $outputs.githubPullRequestsConfig.value
Write-Host "`n--- GitHub Pull Requests ---" -ForegroundColor Cyan
Write-Host "Application ID: $($githubPR.applicationId)" -ForegroundColor White
Write-Host "Credential Resource ID: $($githubPR.credentialResourceId)" -ForegroundColor White
Write-Host "Credential Name: $($githubPR.credentialName)" -ForegroundColor White
Write-Host "Issuer: $($githubPR.issuer)" -ForegroundColor White
Write-Host "Subject: $($githubPR.subject)" -ForegroundColor White

# Display GitHub Environment configuration
$githubEnv = $outputs.githubEnvironmentConfig.value
Write-Host "`n--- GitHub Environment ---" -ForegroundColor Cyan
Write-Host "Application ID: $($githubEnv.applicationId)" -ForegroundColor White
Write-Host "Credential Resource ID: $($githubEnv.credentialResourceId)" -ForegroundColor White
Write-Host "Credential Name: $($githubEnv.credentialName)" -ForegroundColor White
Write-Host "Issuer: $($githubEnv.issuer)" -ForegroundColor White
Write-Host "Subject: $($githubEnv.subject)" -ForegroundColor White

# Display Azure DevOps configuration
$azdo = $outputs.azureDevOpsConfig.value
Write-Host "`n--- Azure DevOps ---" -ForegroundColor Cyan
Write-Host "Application ID: $($azdo.applicationId)" -ForegroundColor White
Write-Host "Credential Resource ID: $($azdo.credentialResourceId)" -ForegroundColor White
Write-Host "Credential Name: $($azdo.credentialName)" -ForegroundColor White
Write-Host "Issuer: $($azdo.issuer)" -ForegroundColor White
Write-Host "Subject: $($azdo.subject)" -ForegroundColor White

# Create summary output file
$outputDir = "./deployment-output"
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$summaryFile = Join-Path $outputDir "deployment-summary.json"
$outputs | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryFile -Encoding UTF8
Write-Host "`nDeployment summary saved to: $summaryFile" -ForegroundColor Gray

Write-Host "`n=== Deployment Summary ===" -ForegroundColor Yellow
$summary = $outputs.deploymentSummary.value
Write-Host "Environment: $($summary.environmentName)" -ForegroundColor White
Write-Host "Organization: $($summary.organizationName)" -ForegroundColor White
Write-Host "Repository: $($summary.repositoryName)" -ForegroundColor White
Write-Host "Total Applications Created: $($summary.totalApplicationsCreated)" -ForegroundColor White
Write-Host "Total Credentials Created: $($summary.totalCredentialsCreated)" -ForegroundColor White

Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. Note the Application IDs above for use in your CI/CD pipelines" -ForegroundColor White
Write-Host "2. Configure your GitHub repository secrets with the Application IDs" -ForegroundColor White
Write-Host "3. Set up Azure DevOps service connections using the Application IDs" -ForegroundColor White
Write-Host "4. Test the OIDC authentication from your external systems" -ForegroundColor White
Write-Host "5. Assign appropriate Azure RBAC roles to the created applications" -ForegroundColor White

Write-Host "`nScript completed successfully!" -ForegroundColor Green

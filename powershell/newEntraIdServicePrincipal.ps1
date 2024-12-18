<#
.SYNOPSIS
Creates a new Entra ID Service Principal and associated Azure AD application.

.DESCRIPTION
This function creates a new Entra ID Service Principal and associated Azure AD application.
If an application with the specified name already exists, it will be removed before creating a new one.
The function also sets up the necessary permissions for the application.

.PARAMETER spName
The name of the service principal to be created.

.PARAMETER funcName
The name of the Azure Function App associated with the service principal.

.PARAMETER entraIdGroupDetails
Details of the Entra ID group (not used in the current implementation).

.OUTPUTS
Hashtable containing the appId and appSecret of the created service principal.

.EXAMPLE
$spDetails = New-EntraIdServicePrincipal -spName "MyServicePrincipal" -funcName "MyFunctionApp" -entraIdGroupDetails "GroupDetails"
Write-Host "App ID: $($spDetails.appId)"
Write-Host "App Secret: $($spDetails.appSecret)"

.NOTES
- Requires Azure CLI to be installed and authenticated.
- The function assumes that the Azure Function App name is unique and accessible.

- Author
Simon Lee
Twitter: https://twitter.com/smoon_lee
Blog: https://blog.builtwithcaffeine.cloud
GitHub (Personal): https://github.com/smoonlee
GitHub (BuiltWithCaffeine): https://github.com/builtwithcaffeine
#>

function New-EntraIdServicePrincipal {
    param (
        [string] $spName,
        [string] $funcName,
        [string] $entraIdGroupDetails
    )
    # Check if the service principal name already exists
    $existingApp = az ad app list --display-name $spName --query "[].appId" -o 'tsv'

    if ($existingApp) {
        Write-Host "`nAn application with the name $spName already exists with AppId: $existingApp. Removing it."

        # Remove the existing application
        az ad app delete --id $existingApp

        Write-Host "Existing application and service principal removed."
    }

    # Function App Urls
    $funcWebPageUrl = "https://$funcName.azurewebsites.net"
    $funcUrlCallBack = "https://$funcName.azurewebsites.net/.auth/login/aad/callback"

    # Create a new Azure AD application
    Write-Host "`nCreating Entra Id Enterprise Application: $spName"
    $app = az ad app create `
        --display-name $spName `
        --enable-id-token-issuance true `
        --web-home-page-url $funcWebPageUrl `
        --web-redirect-uris $funcUrlCallBack `
        --query "{appId: appId}" -o json | ConvertFrom-Json

    # Verbose
    Write-Host "Enterprise Application Created: $($app.appId)"

    # Create a new service principal for the application
    Write-Host "`nCreating Entra Id Service Principal: $spName"
    $spAppId = az ad sp create --id $app.appId --query 'appId' --output 'tsv'
    $spAppSecret = az ad app credential reset --id $spAppId --query 'password' --output 'tsv' --only-show-errors

    # Add the required permissions to the application
    az ad app permission add `
        --id $spAppId `
        --api 00000003-0000-0000-c000-000000000000 `
        --api-permissions `
        e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope `
        37f7f235-527c-4136-accd-4a02d197296e=Scope `
        64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0=Scope `
        14dad69e-099b-42c9-810b-d002981feec1=Scope `
        --only-show-errors --output none

    Write-Host "Service Principal Created: $spAppId)"

    # Return a hashtable with the appId and appSecret
    return @{
        appId     = $spAppId
        appSecret = $spAppSecret
    }
}
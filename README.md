# Key Vault ACME :: Bicep Deployment
This repository is based on the keyvault-acmebot project, which is an open-source tool designed to automate the issuance and renewal of SSL/TLS certificates using the ACME (Automated Certificate Management Environment) protocol, specifically integrating with Azure Key Vault.

> [!NOTE]
> This side project is being activily worked on. I'm currently looking at the Private EndPoint configuration options to ensure a more secure deployment option. - 
> Simon - December 2024

## Project Overview
The [keyvault-acme](https://github.com/shibayan/keyvault-acmebot) project automates SSL/TLS certificate management in Azure Key Vault using the ACME protocol. It helps users request, store, and renew certificates with minimal manual intervention, making it especially useful for Azure-hosted websites and services.

### Key Components
- ACME Protocol: The protocol used by certificate authorities like Let's Encrypt to automate certificate issuance, renewal, and revocation.
- Azure Key Vault: Azure's cloud service for securely managing secrets, keys, and certificates.
- keyvault-acme Project: Automates SSL/TLS certificate management in Azure Key Vault using ACME-compliant certificate authorities (e.g., Let's Encrypt).

### Features
- Automated Certificate Requests: Automatically requests SSL/TLS certificates from ACME-compliant authorities.
- Secure Storage: Stores issued certificates securely in Azure Key Vault.
- Automated Renewal: Automatically renews certificates before expiration.

This project simplifies SSL certificate management for Azure users, reducing the need for manual intervention.

> [!NOTE]
> This deployment focuses mainly on Azure DNS Zones.

This said though, the Keyvault ACME project supports lots more DNS Providers. [DNS-Provider-Configuration](https://github.com/shibayan/keyvault-acmebot/wiki/DNS-Provider-Configuration)

## Deployment Instructions
### Prerequisites
Before you begin, ensure that you have both Azure CLI and Azure Bicep installed. To install, run the following in an administrative context:

``` powershell
$appList = ('Git.Git', 'Microsoft.AzureCLI', 'Microsoft.Bicep')
foreach ($app in $appList) {
    winget install --scope Machine --exact --id $app
}
```

### Clone the Repository

>Clone the repository to your local machine:
>
``` powershell
git clone https://github.com/builtwithcaffeine/bwc-keyvault-acme-bicep.git
Set-Location -Path 'bwc-keyvault-acme-bicep'
```
## Configure Parameters
Open `deployNow.ps1` and customize the parameters in the `$kvacmeparams` hash table to suit your environment:

``` powershell
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
```

## Execute the Bicep Deployment
Run the deployment script to create and configure the necessary resources. Replace <subscription-id> with your Azure subscription ID, and specify the environment type (e.g., [dev], [acc], or [prod]):

``` powershell
.\deployNow.ps1 -subscriptionId <subscription-id> -environmentType [dev|acc|prod] -location westeurope -deploy
```

### Deployment Diagram

![image](https://github.com/user-attachments/assets/188e128f-7993-417e-bf2b-ddff118e8931)

## Operating Instructions
Once the deployment is completed, (Takes around 5 miuntes, after 6 hours of build time :D). Head to the function app and open the Default domain url:

![](https://github.com/user-attachments/assets/95de93b9-3a16-442d-8fe8-8782374969b8)

### First Time 
When you first open the function app, You'll need to authenticate the Enterprise App.

![](https://github.com/user-attachments/assets/491bd256-f77b-47c0-8c7b-9b0465dcc42d)

## Key Vault ACME Portal

![](https://github.com/user-attachments/assets/21c07349-8b2e-47ce-9eba-749aa8b80501)

Here is the portal for the Key Vault ACME, If you want to create a record click `Add`
From the DNS Zone, You can pick from Azure Public DNS or Azure Private DNS Zone.

![](https://github.com/user-attachments/assets/24abc19c-7b15-4f02-aaa5-709e03979652)

<details closed>
<summary>Advanced Options</summary>
<br>

![](https://github.com/user-attachments/assets/11d2047a-cd9d-4861-8525-6cb8b64832e4)

</details>

Click Add, 

![](https://github.com/user-attachments/assets/5ad558b0-cc8f-4bfc-b859-2aab91255ee9)

Finally, Checking the Azure Key Vault we can see the certificate 

![](https://github.com/user-attachments/assets/542e0a5c-b0e1-4884-ad84-86047579c9d1)


> [!IMPORTANT]
> Please note, this solution uses **Access Policies** for Access/Authentication



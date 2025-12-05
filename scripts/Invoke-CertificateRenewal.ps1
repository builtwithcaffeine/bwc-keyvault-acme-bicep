# Script Variables
$keyVaultName = 'kv-builtwithcaffeine-dev-weu'
$certificateNames = (
    '<certificate>.builtwithcaffeine.cloud',
)

#
# Script Logging
#

$dateTimeStamp = Get-Date -format 'yyyy-mm-dd-HH-mm-ss'
$logPath = "C:\Log\$($dateTimeStamp)_certRenewal.txt"

If (!(Test-Path -Path $($logPath | Split-Path -Parent))) {
    New-Item -ItemType 'Directory' -Path $($logPath | Split-Path -Parent) | Out-Null
}

Start-Transcript -Path $logPath

Write-Output "-------------------------------------------"
Write-Output "  Key Vault ACME :: Certificate Installer  "
Write-Output "-------------------------------------------"

#
# Configure PowerShell
#

Write-Output "--> Checking PSGallery and NuGet Packages"

$installationPolicyState = (Get-PSRepository -Name 'PSGallery').InstallationPolicy
if ($installationPolicyState -ne 'Trusted') {
    # Install Latest NuGet Package Provider
    Write-Output "Installing Latest NuGet Package Release"
    Install-PackageProvider -Name NuGet -Force | Out-Null

    # Update PSGallery InstallationPolicy State
    Write-Output "Updating PSGallery InstallationPolicy [Trusted]"
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
}
else {
    Write-Output "PSGallery 'Trusted', NuGet PackageProvider Ok!" `r
}

#
# Install Azure PowerShell Required Modules
#

Write-Output "--> Checking PowerShell Modules" `r

$azModules = @(
    'Az.Accounts',
    'Az.Resources',
    'Az.Keyvault'
)

foreach ($moduleName in $azModules) {
    Write-Output "Checking for $moduleName"
    $module = Get-Module -ListAvailable $moduleName
    if (-not $module) {
        Write-Warning "$moduleName missing, Installing now!"
        Install-Module -Name $moduleName -Force
    }
    else {
        Write-Output "Module: $($module.name), Version: $($module.version)" `r
    }
}

#
# Connect to Azure Environment
#

Write-Output "--> Authenticating to Azure (System Assigned Identity)"
$status = Connect-AzAccount -Identity
Write-Output "Welcome to $($status.Context.Subscription.Name)!" `r

Write-Output "--> Checking Certificates in Key Vault [$keyVaultName]"
$certDataList = @()

foreach ($certificate in $certificateNames) {
    try {
        $certRequest = Get-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificate.Replace('.', '-')
        $certDataList += [PSCustomObject]@{
            Name       = $certRequest.Name
            CreatedOn  = $certRequest.Created.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
            ExpiresOn  = $certRequest.Expires.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
            Thumbprint = $certRequest.Thumbprint
        }
    }
    catch {
        Write-Warning "Error retrieving certificate $($certificate): $_"
    }
}

# Output the entire list as a clean table
$certDataList | Format-Table -AutoSize

Write-Output "--> Download Certificates in Key Vault [$keyVaultName]"
foreach ($certificate in $certDataList) {
    $pfxSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $certificate.Name -AsPlainText
    $pfxBytes = [Convert]::FromBase64String($pfxSecret)
    $flags = 'MachineKeySet,Exportable,PersistKeySet'
    $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new()
    $cert.Import($pfxBytes, $null, $flags)

    $store = [Security.Cryptography.X509Certificates.X509Store]::new('My', 'LocalMachine')
    $store.Open('ReadWrite')
    $exists = $store.Certificates.Find('FindByThumbprint', $cert.Thumbprint, $false)
    if ($exists.Count -eq 0) {
        Write-Output "--> Installing Certificate [$($certificate.Name)] to Local Certificate Store"
    }

    if ($exists.Count -eq 1) {
        Write-Output "--> Checking Certificate [$($certificate.Name)] in Local Certificate Store"
    }

    try {
        # Check if the certificate already exists in the store
        $exists = $store.Certificates.Find('FindByThumbprint', $cert.Thumbprint, $false)

        if ($exists.Count -eq 0) {
            $store.Add($cert)
            Write-Output "--> Certificate Installed Successfully! - $($cert.Thumbprint)" `r
        }
        else {
            # Check the expiration of the certificate in the local store
            $localCert = $exists[0]
            $expiryThreshold = (Get-Date).AddDays(7)  # Certificates that will expire in 7 days or less
            $daysToExpire = ($localCert.NotAfter - (Get-Date)).Days  # Calculate remaining days

            if ($localCert.NotAfter -lt $expiryThreshold) {
                Write-Output "--> Certificate [$($certificate.Name)] in local store is expiring soon. Updating..."
                # Remove the old certificate and install the new one
                $store.Remove($localCert)
                $store.Add($cert)
                Write-Output "--> Certificate Updated Successfully! - $($cert.Thumbprint)" `r
            }
            else {
                Write-Output "--> Certificate [$($certificate.Name)] is valid in local store - $($cert.Thumbprint)."
                Write-Output "--> Expiration Date: $($localCert.NotAfter.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')), Days Remaining: $daysToExpire. No update required." `r
            }
        }
    }
    finally { $store.Close() }
}

#
# Information Internet Services
#

$iisCheck = (Get-WindowsFeature -Name 'Web-Server').InstallState
if ($iisCheck -eq 'Installed') {

    foreach ($certificate in $certificateNames) {

        Write-Output "--> Checking IIS Binding for Certificate - [$certificate]"

        # Get SSL site bindings
        $sslSiteBindings = Get-WebBinding -Protocol 'https'

        # Filter bindings for the certificate in the bindingInformation
        $filteredBindings = $sslSiteBindings | Where-Object { $_.bindingInformation -like "*:$certificate" }

        # Check if any bindings matched and output result
        if ($filteredBindings) {
            Write-Output "--> Binding found for [$certificate]: $($filteredBindings.bindingInformation)"
            $sslBinding = $filteredBindings

            Write-Output "--> Removing Old Certificate: [$($sslBinding.certificateHash)]"
            $sslBinding.RemoveSslCertificate()

            Write-Output "--> Adding New Certificate: [$($cert.Thumbprint)]" `r
            $sslBinding.AddSslCertificate($cert.Thumbprint, 'My')
        }
        else {
            Write-Output "No binding found for [$certificate]." `r
        }
    }
}

Stop-Transcript

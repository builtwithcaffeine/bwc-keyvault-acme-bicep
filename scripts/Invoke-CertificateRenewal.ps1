[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $KeyVaultName = 'kv-builtwithcaffeine-dev-weu',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int] $RenewalThresholdDays = 7,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string] $LogDirectory = 'C:\Log',

    [Parameter(Mandatory = $false)]
    [switch] $AllowInteractiveLoginFallback,

    [Parameter(Mandatory = $false)]
    [switch] $InstallMissingModules,

    [Parameter(Mandatory = $false)]
    [bool] $FailIfNoCertificates = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script Variables
$certificateNames = @(
    '<certificate>.builtwithcaffeine.cloud'
)

function Install-RequiredModule {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $module = Get-Module -ListAvailable -Name $Name
    if (-not $module) {
        if (-not $InstallMissingModules) {
            throw "Required module [$Name] is not installed. Install it ahead of schedule run, or re-run with -InstallMissingModules."
        }

        Write-Warning "$Name missing, installing to CurrentUser scope..."
        Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -Confirm:$false
    }
    else {
        $latest = $module | Sort-Object Version -Descending | Select-Object -First 1
        Write-Output "Module: $($latest.Name), Version: $($latest.Version)"
    }
}

function Connect-AzContext {
    Write-Output "--> Authenticating to Azure (Managed Identity)"
    try {
        $status = Connect-AzAccount -Identity
        if ($SubscriptionId) {
            Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        }
        Write-Output "Welcome to $($status.Context.Subscription.Name)!"
        return
    }
    catch {
        if (-not $AllowInteractiveLoginFallback) {
            throw "Managed Identity authentication failed. Re-run with -AllowInteractiveLoginFallback to use interactive login. Error: $($_.Exception.Message)"
        }

        Write-Warning "Managed Identity authentication failed, falling back to interactive login..."
        $status = Connect-AzAccount
        if ($SubscriptionId) {
            Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        }
        Write-Output "Welcome to $($status.Context.Subscription.Name)!"
    }
}

# Script Logging
$dateTimeStamp = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
$logPath = Join-Path -Path $LogDirectory -ChildPath "${dateTimeStamp}_certRenewal.txt"
$transcriptStarted = $false
$hasProcessingErrors = $false

try {
    if (-not (Test-Path -Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory | Out-Null
    }

    Start-Transcript -Path $logPath
    $transcriptStarted = $true

    Write-Output "-------------------------------------------"
    Write-Output "  Key Vault ACME :: Certificate Installer  "
    Write-Output "-------------------------------------------"
    Write-Output "Execution mode: unattended-safe (non-interactive default)"

    # Configure PowerShell / modules
    if ($InstallMissingModules) {
        Write-Output "--> Preparing PSGallery and NuGet (InstallMissingModules enabled)"
        $installationPolicyState = (Get-PSRepository -Name 'PSGallery').InstallationPolicy
        if ($installationPolicyState -ne 'Trusted') {
            Write-Output "Installing Latest NuGet Package Release"
            Install-PackageProvider -Name NuGet -Force | Out-Null

            Write-Output "Updating PSGallery InstallationPolicy [Trusted]"
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        }
        else {
            Write-Output "PSGallery 'Trusted', NuGet PackageProvider Ok!"
        }
    }
    else {
        Write-Output "--> Skipping PSGallery changes (InstallMissingModules not set)"
    }

    Write-Output "--> Checking PowerShell Modules"
    @(
        'Az.Accounts',
        'Az.Resources',
        'Az.KeyVault'
    ) | ForEach-Object {
        Install-RequiredModule -Name $_
    }

    # Connect to Azure
    Connect-AzContext

    # Retrieve Key Vault certificate metadata
    Write-Output "--> Checking Certificates in Key Vault [$KeyVaultName]"
    $certDataList = @()

    foreach ($certificateHostName in $certificateNames) {
        try {
            $certificateName = $certificateHostName.Replace('.', '-')
            $certRequest = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $certificateName
            $certDataList += [PSCustomObject]@{
                HostName   = $certificateHostName
                Name       = $certRequest.Name
                CreatedOn  = $certRequest.Created.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
                ExpiresOn  = $certRequest.Expires.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
                Thumbprint = $certRequest.Thumbprint
            }
        }
        catch {
            Write-Warning "Error retrieving certificate [$certificateHostName]: $($_.Exception.Message)"
            $hasProcessingErrors = $true
        }
    }

    if (-not $certDataList -or $certDataList.Count -eq 0) {
        $message = "No certificates were retrieved from Key Vault [$KeyVaultName]."
        if ($FailIfNoCertificates) {
            throw $message
        }

        Write-Warning $message
        return
    }

    $certDataList | Format-Table -AutoSize

    # Install/update certificates in local machine store
    Write-Output "--> Downloading certificates from Key Vault [$KeyVaultName]"
    $installedCertThumbprintsByHostName = @{}

    foreach ($certificate in $certDataList) {
        try {
            $pfxSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $certificate.Name -AsPlainText
            $pfxBytes = [Convert]::FromBase64String($pfxSecret)
            $flags = 'MachineKeySet,Exportable,PersistKeySet'
            $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new()
            $cert.Import($pfxBytes, $null, $flags)

            $store = [Security.Cryptography.X509Certificates.X509Store]::new('My', 'LocalMachine')
            $store.Open('ReadWrite')
            try {
                $existingByThumbprint = $store.Certificates.Find('FindByThumbprint', $cert.Thumbprint, $false)
                if ($existingByThumbprint.Count -eq 0) {
                    Write-Output "--> Installing certificate [$($certificate.Name)] to LocalMachine\\My"
                    $store.Add($cert)
                    Write-Output "--> Certificate installed successfully: $($cert.Thumbprint)"
                }
                else {
                    $localCert = $existingByThumbprint[0]
                    $expiryThreshold = (Get-Date).AddDays($RenewalThresholdDays)
                    $daysToExpire = ($localCert.NotAfter - (Get-Date)).Days

                    if ($localCert.NotAfter -lt $expiryThreshold) {
                        Write-Output "--> Certificate [$($certificate.Name)] expires in $daysToExpire day(s); updating..."
                        $store.Remove($localCert)
                        $store.Add($cert)
                        Write-Output "--> Certificate updated successfully: $($cert.Thumbprint)"
                    }
                    else {
                        Write-Output "--> Certificate [$($certificate.Name)] is valid in local store. Expires: $($localCert.NotAfter.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) (in $daysToExpire day(s))."
                    }
                }

                $installedCertThumbprintsByHostName[$certificate.HostName] = $cert.Thumbprint
            }
            finally {
                $store.Close()
            }
        }
        catch {
            Write-Warning "Failed processing certificate [$($certificate.HostName)]: $($_.Exception.Message)"
            $hasProcessingErrors = $true
        }
    }

    # Update IIS bindings (if available)
    $canManageIis = $false
    if (Get-Command -Name Get-WindowsFeature -ErrorAction SilentlyContinue) {
        $iisCheck = (Get-WindowsFeature -Name 'Web-Server').InstallState
        $canManageIis = $iisCheck -eq 'Installed'
    }
    elseif (Get-Command -Name Get-WebBinding -ErrorAction SilentlyContinue) {
        $canManageIis = $true
    }

    if ($canManageIis) {
        if (-not (Get-Command -Name Get-WebBinding -ErrorAction SilentlyContinue)) {
            Import-Module WebAdministration -ErrorAction Stop
        }

        foreach ($certificateHostName in $certificateNames) {
            Write-Output "--> Checking IIS HTTPS bindings for host [$certificateHostName]"

            if (-not $installedCertThumbprintsByHostName.ContainsKey($certificateHostName)) {
                Write-Warning "Skipping IIS update for [$certificateHostName] - no installed thumbprint found."
                $hasProcessingErrors = $true
                continue
            }

            $targetThumbprint = $installedCertThumbprintsByHostName[$certificateHostName]
            $sslSiteBindings = Get-WebBinding -Protocol 'https'
            $filteredBindings = @($sslSiteBindings | Where-Object { $_.bindingInformation -like "*:$certificateHostName" })

            if ($filteredBindings.Count -eq 0) {
                Write-Output "No IIS HTTPS binding found for [$certificateHostName]."
                continue
            }

            foreach ($sslBinding in $filteredBindings) {
                Write-Output "--> Binding found: $($sslBinding.bindingInformation)"
                Write-Output "--> Replacing certificate hash [$($sslBinding.certificateHash)] with [$targetThumbprint]"

                $sslBinding.RemoveSslCertificate()
                $sslBinding.AddSslCertificate($targetThumbprint, 'My')
            }
        }
    }
    else {
        Write-Output "--> IIS not detected; skipping IIS binding updates."
    }

    if ($hasProcessingErrors) {
        throw 'One or more certificate operations reported errors. Review transcript log for details.'
    }

    Write-Output '--> Certificate renewal task completed successfully.'
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}

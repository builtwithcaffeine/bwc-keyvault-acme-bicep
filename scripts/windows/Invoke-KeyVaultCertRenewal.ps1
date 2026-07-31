# Requires -RunAsAdministrator
<#
.SYNOPSIS
    Renews an IIS-bound TLS certificate from Azure Key Vault using the VM's managed identity.
#>

$ErrorActionPreference = 'Stop'
# Native commands (az, netsh, iisreset) signal failure via exit code, not stderr -
# checked explicitly throughout this script, so don't let a non-zero exit code
# also throw a terminating error (PowerShell 7.3+ default behavior).
$PSNativeCommandUseErrorActionPreference = $false

# Manual overrides - set either to skip auto-detection, leave empty to auto-detect
$KeyVaultName = ''
$AzureClientId = ''

# Log rotation configuration
$LogDir = 'C:\ProgramData\KeyVaultCertRenewal'
$LogFile = Join-Path $LogDir 'keyvault-cert-renewal.log'

# Prevent overlapping runs (e.g. a slow run still executing when the scheduled task fires again)
$LockMutex = New-Object System.Threading.Mutex($false, 'Global\KeyVaultCertRenewal')
if (-not $LockMutex.WaitOne(0)) {
  Write-Host "$(Get-Date) another run is already in progress, exiting"
  exit 1
}

# Older Windows Server defaults to TLS 1.0/1.1, which modern endpoints (aka.ms, Key Vault) may reject
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---- Formatting helpers -----------------------------------------------------

function Get-Ts { (Get-Date).ToString('[ yyyy-MM-dd - HH:mm:ss ]') }

function Write-Line([string]$Text, [ConsoleColor]$Color = 'Gray') {
  $line = "$(Get-Ts) $Text"
  Write-Host $line -ForegroundColor $Color
  Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Step($Message) { Write-Host ''; Write-Line "==> $Message" Cyan }
function Info($Message) { Write-Line "    $Message" Gray }
function Success($Message) { Write-Line "OK  $Message" Green }
function Warn($Message) { Write-Line "!!  $Message" Yellow }
function Fail($Message) { Write-Line "XX  $Message" Red; exit 1 }

# Runs a native command without letting stderr output become a terminating
# error under $ErrorActionPreference = 'Stop' - merges streams and checks
# $LASTEXITCODE explicitly instead. Used for az, netsh, and iisreset alike,
# since all three can write to stderr on non-fatal conditions.
function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$ArgumentList
  )
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $stderrLines = $null
  try {
    # stdout/stderr captured separately (not merged) so a stray stderr warning
    # can never corrupt a captured stdout value, e.g. a base64 secret
    $stdoutLines = & $FilePath @ArgumentList 2>$stderrLines
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prevEap
  }
  $stdoutArr = @($stdoutLines | ForEach-Object { "$_" })
  $stderrArr = @($stderrLines | ForEach-Object { "$_" })
  [PSCustomObject]@{
    Output = $stdoutArr
    Text = (($stdoutArr + $stderrArr) -join "`n")
    ExitCode = $exitCode
    Success = ($exitCode -eq 0)
  }
}

function Invoke-Az {
  param([Parameter(Mandatory)][string[]]$ArgumentList)
  Invoke-Native -FilePath 'az' -ArgumentList $ArgumentList
}

# ---- Ensuring log rotation ---------------------------------------------------

step "Ensuring log rotation"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# Restrict the log directory to SYSTEM/Administrators - ProgramData is otherwise
# readable by any authenticated user by default
$acl = Invoke-Native -FilePath 'icacls' -ArgumentList @($LogDir, '/inheritance:r', '/grant:r', 'SYSTEM:(OI)(CI)F', 'BUILTIN\Administrators:(OI)(CI)F')
if (-not $acl.Success) { Warn "Could not restrict log directory permissions: $($acl.Text)" }

if ((Test-Path $LogFile) -and ((Get-Item $LogFile).LastWriteTime.Date -ne (Get-Date).Date)) {
  $archiveName = "keyvault-cert-renewal-{0:yyyyMMdd}.log" -f (Get-Item $LogFile).LastWriteTime
  Rename-Item -Path $LogFile -NewName $archiveName -ErrorAction SilentlyContinue
}

Get-ChildItem -Path $LogDir -Filter 'keyvault-cert-renewal-*.log' -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
  Remove-Item -Force -ErrorAction SilentlyContinue

Success "Log rotation configured: ${LogDir} (30 days)"

# ---- Checking Azure CLI -------------------------------------------------------

Step "Checking Azure CLI"
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  Warn "Azure CLI not found, installing..."
  $installer = "$env:TEMP\AzureCLI.msi"
  Invoke-WebRequest -Uri 'https://aka.ms/installazurecliwindows' -OutFile $installer -UseBasicParsing

  # Verify the downloaded installer is genuinely signed by Microsoft before executing it
  $signature = Get-AuthenticodeSignature -FilePath $installer
  if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
    Remove-Item $installer -ErrorAction SilentlyContinue
    Fail "Azure CLI installer failed signature verification (status: $($signature.Status)); refusing to run it"
  }

  $msiArgs = @('/I', "`"$installer`"", '/quiet', '/norestart', '/L*V', "`"$env:TEMP\AzureCLI-install.log`"")
  $proc = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
  Remove-Item $installer -ErrorAction SilentlyContinue

  if ($proc.ExitCode -ne 0) {
    Fail "Azure CLI install failed with exit code $($proc.ExitCode). See $env:TEMP\AzureCLI-install.log for details."
  }

  # Refresh PATH from the machine + user environment (msiexec updates the registry, not this process)
  $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machinePath;$userPath"
}
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  Fail "Azure CLI installation could not be verified. Install manually and re-run."
}
Success "Azure CLI available"

# ---- Detecting web server (IIS) ------------------------------------------------

Step "Detecting web server"
if (-not (Get-Service -Name W3SVC -ErrorAction SilentlyContinue)) {
  Fail "IIS (W3SVC) is not installed on this host"
}
Import-Module WebAdministration -ErrorAction Stop
Success "Detected web server: IIS"

Step "Collecting server names from IIS bindings"
$serverNames = @(Get-WebBinding |
  Where-Object { $_.protocol -eq 'https' -and $_.bindingInformation -match '\S+$' } |
  ForEach-Object { ($_.bindingInformation -split ':')[-1] } |
  Where-Object { $_ -and $_ -ne '*' } |
  Sort-Object -Unique)

if (-not $serverNames -or $serverNames.Count -eq 0) {
  Fail "No https bindings with a host name found in IIS. Add a host name to a site binding (e.g. 'example.com') and re-run."
}

Success "Found $($serverNames.Count) server name(s)"
$serverNames | ForEach-Object { Info "- $_" }

# ---- Authenticating to Azure ----------------------------------------------------

Step "Authenticating to Azure"
$accountCheck = Invoke-Az @('account', 'show')
if (-not $accountCheck.Success) {
  Info "Logging in using managed identity..."
  if ($AzureClientId) {
    $login = Invoke-Az @('login', '--identity', '--username', $AzureClientId)
  } else {
    $login = Invoke-Az @('login', '--identity')
  }
  if (-not $login.Success) {
    Fail "az login --identity failed: $($login.Text)"
  }
}
Success "Authenticated to Azure"

# ---- Locating Key Vault -----------------------------------------------------------

Step "Locating Key Vault"
if ($KeyVaultName) {
  Info "Using manual override"
} else {
  $keyVaultsResult = Invoke-Az @('keyvault', 'list', '--query', '[].name', '-o', 'tsv')
  if (-not $keyVaultsResult.Success) {
    Fail "az keyvault list failed: $($keyVaultsResult.Text)"
  }
  $keyVaultList = @($keyVaultsResult.Output | Where-Object { $_ })

  if ($keyVaultList.Count -eq 0) {
    Fail "No Key Vault accessible to this managed identity"
  } elseif ($keyVaultList.Count -gt 1) {
    Fail "Expected exactly one accessible Key Vault, found $($keyVaultList.Count): $($keyVaultList -join ', ')"
  }

  $KeyVaultName = $keyVaultList[0]
}
Success "Using Key Vault: $KeyVaultName"

# ---- Matching certificate -----------------------------------------------------------

Step "Matching certificate"
$vaultCertNamesResult = Invoke-Az @('keyvault', 'certificate', 'list', '--vault-name', $KeyVaultName, '--query', '[].name', '-o', 'tsv')
if (-not $vaultCertNamesResult.Success) {
  Fail "az keyvault certificate list failed: $($vaultCertNamesResult.Text)"
}
$vaultCertNames = @($vaultCertNamesResult.Output | Where-Object { $_ })

$certName = $null
foreach ($serverName in $serverNames) {
  foreach ($vaultCertName in $vaultCertNames) {
    $sansResult = Invoke-Az @('keyvault', 'certificate', 'show', '--vault-name', $KeyVaultName, '--name', $vaultCertName, '--query', 'policy.x509CertificateProperties.subjectAlternativeNames.dnsNames', '-o', 'tsv')
    if ($sansResult.Success -and ($sansResult.Output -contains $serverName)) {
      $certName = $vaultCertName
      break
    }
  }
  if ($certName) { break }
}

if (-not $certName) {
  Fail "No certificate found in $KeyVaultName matching: $($serverNames -join ', ')"
}

Success "Found certificate: $certName"
Info "Windows certificate store: Cert:\LocalMachine\My"

# ---- Checking certificate status -----------------------------------------------------

Step "Checking certificate status"
# Uses only the public certificate (cer) and metadata - no secret access, no local changes
$vaultCerResult = Invoke-Az @('keyvault', 'certificate', 'show', '--vault-name', $KeyVaultName, '--name', $certName, '--query', 'cer', '-o', 'tsv')
if (-not $vaultCerResult.Success) {
  Fail "Failed to read certificate '$certName' from Key Vault '$KeyVaultName': $($vaultCerResult.Text)"
}
$vaultCerB64 = $vaultCerResult.Text
if (-not $vaultCerB64) {
  Fail "Certificate '$certName' returned no public certificate (cer) data"
}

$vaultCertBytes = [Convert]::FromBase64String($vaultCerB64)
$vaultCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$vaultCertBytes)
$vaultFingerprint = $vaultCert.Thumbprint
$vaultExpiry = $vaultCert.NotAfter
$expiryDays = [int]([TimeSpan]($vaultExpiry - (Get-Date))).TotalDays
Info "Expires: $vaultExpiry ($expiryDays days remaining)"
if ($expiryDays -lt 0) {
  Warn "Vault certificate '$certName' has already expired"
}

$localCert = Get-ChildItem Cert:\LocalMachine\My |
  Where-Object { $_.Subject -match [regex]::Escape($serverNames[0]) } |
  Select-Object -First 1
$localFingerprint = if ($localCert) { $localCert.Thumbprint } else { '' }

if ($vaultFingerprint -eq $localFingerprint) {
  Write-Host ''
  Success "Certificate $certName is already up to date, nothing to do."
  exit 0
}

# ---- Downloading certificate -----------------------------------------------------------

Step "Downloading certificate"
# Certificates are stored as PFX-encoded secrets alongside the certificate object
$secretResult = Invoke-Az @('keyvault', 'secret', 'show', '--vault-name', $KeyVaultName, '--name', $certName, '--query', 'value', '-o', 'tsv')
if (-not $secretResult.Success) {
  Fail "Failed to read secret '$certName' from Key Vault '$KeyVaultName': $($secretResult.Text)"
}
$pfxBytes = [Convert]::FromBase64String($secretResult.Text)
$tmpPfx = Join-Path ([System.IO.Path]::GetTempPath()) "$certName.pfx"
[System.IO.File]::WriteAllBytes($tmpPfx, $pfxBytes)
[Array]::Clear($pfxBytes, 0, $pfxBytes.Length)
$secretResult = $null
Success "Certificate downloaded and decoded"

# ---- Installing certificate -----------------------------------------------------------

Step "Installing certificate"
$securePassword = New-Object System.Security.SecureString
try {
  # Not -Exportable: the private key only needs to be usable by IIS, never extractable afterwards
  $newCert = Import-PfxCertificate -FilePath $tmpPfx -CertStoreLocation Cert:\LocalMachine\My -Password $securePassword
} finally {
  # Guarantee the private-key-bearing temp file is removed even if the import fails
  Remove-Item $tmpPfx -Force -ErrorAction SilentlyContinue
  $securePassword.Dispose()
}

if ($newCert.Thumbprint -ne $vaultFingerprint) {
  Fail "Imported certificate thumbprint ($($newCert.Thumbprint)) does not match Key Vault ($vaultFingerprint)"
}

Info "Thumbprint: $($newCert.Thumbprint)"
Success "Certificate installed"

# ---- Updating IIS bindings and reloading --------------------------------------------------

Step "Updating IIS bindings"
# SNI (host-header) bindings store their certificate mapping directly in applicationHost.config,
# set via the binding's own AddSslCertificate method - not via netsh's HTTP.SYS sslcert store,
# which IIS Manager's "SSL certificate" dropdown does not read for these bindings.
$bindings = Get-WebBinding | Where-Object { $_.protocol -eq 'https' -and (($_.bindingInformation -split ':')[-1]) -in $serverNames }
foreach ($binding in $bindings) {
  $hostName = ($binding.bindingInformation -split ':')[-1]
  try {
    $binding.AddSslCertificate($newCert.Thumbprint, 'my')
  } catch {
    Fail "Failed to bind certificate for ${hostName}: $($_.Exception.Message)"
  }
  Info "Bound $hostName to thumbprint $($newCert.Thumbprint)"
}

$reset = Invoke-Native -FilePath 'iisreset' -ArgumentList @('/noforce')
if (-not $reset.Success) {
  Fail "iisreset failed: $($reset.Text)"
}
Success "IIS reloaded"

# Remove the superseded certificate only after the new one is confirmed bound and IIS reloaded
if ($localCert) {
  Remove-Item -Path "Cert:\LocalMachine\My\$($localCert.Thumbprint)" -Force -ErrorAction SilentlyContinue
}

Step "Done"
Success "Certificate $certName installed and IIS reloaded"

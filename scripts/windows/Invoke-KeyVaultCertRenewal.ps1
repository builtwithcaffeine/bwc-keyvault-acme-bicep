# Requires -RunAsAdministrator
<#
.SYNOPSIS
    Renews IIS TLS certificates from Azure Key Vault using the VM's managed identity.

.DESCRIPTION
    Collects the host names bound in IIS, looks up a matching certificate for each in
    Key Vault, and installs any that have changed. The PFX is never written to disk in
    the clear - it is imported straight from memory into the LocalMachine store, or
    re-encrypted in memory before being written to the Central Certificate Store.

.PARAMETER KeyVaultName
    Skips vault auto-detection.

.PARAMETER ClientId
    Client ID of a user-assigned managed identity to authenticate with.

.PARAMETER CentralCertStorePassword
    The IIS Central Certificate Store private key password. Required only when CCS is
    enabled, because every PFX in the store share is encrypted with it.

.PARAMETER NoBindingCreate
    Never create an https binding, only update certificates on existing ones.

.PARAMETER RestartIis
    Run iisreset after applying. Not normally needed - binding changes take effect
    immediately - but available for sites that cache certificates in-process.

.PARAMETER DryRun
    Report what would change without installing or binding anything.
#>
[CmdletBinding()]
param(
  [string]$KeyVaultName = $env:KEY_VAULT_NAME,
  [string]$ClientId = $env:AZURE_CLIENT_ID,
  [System.Security.SecureString]$CentralCertStorePassword,
  [switch]$NoBindingCreate,
  [switch]$RestartIis,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
# Native commands (az, iisreset) signal failure via exit code, not stderr - checked
# explicitly throughout this script, so don't let a non-zero exit code also throw a
# terminating error (PowerShell 7.3+ default behavior).
$PSNativeCommandUseErrorActionPreference = $false

$LogDir = 'C:\ProgramData\KeyVaultCertRenewal'
$LogFile = Join-Path $LogDir 'keyvault-cert-renewal.log'
$BackupRoot = Join-Path $LogDir 'backups'
$ExpiryWarningDays = 14

# Bit 2 of a binding's sslFlags means "use the Central Certificate Store", bit 1 means SNI
$SslFlagSni = 1
$SslFlagCcs = 2

# Prevent overlapping runs (e.g. a slow run still executing when the scheduled task fires again)
$LockMutex = New-Object System.Threading.Mutex($false, 'Global\KeyVaultCertRenewal')
if (-not $LockMutex.WaitOne(0)) {
  Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') !!  another run is already in progress, exiting"
  exit 1
}

# Older Windows Server defaults to TLS 1.0/1.1, which modern endpoints (aka.ms, Key Vault) may reject
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---- Logging helpers --------------------------------------------------------

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Emit {
  param(
    [string]$Tag,
    [string]$Text,
    [ConsoleColor]$Color = 'Gray'
  )
  $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $line = '{0} {1,-3} {2}' -f $now, $Tag, $Text
  Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
  Write-Host $line -ForegroundColor $Color
}

function Step { param($Message) Write-Host ''; Write-Emit '==>' $Message Cyan }
function Info { param($Message) Write-Emit '' $Message Gray }
function Detail { param($Message) Write-Emit '' "  $Message" DarkGray }
function Success { param($Message) Write-Emit 'OK' $Message Green }
function Warn { param($Message) Write-Emit '!!' $Message Yellow }
function Fail { param($Message) Write-Emit 'XX' $Message Red; exit 1 }

# Runs a native command without letting stderr output become a terminating
# error under $ErrorActionPreference = 'Stop' - checks $LASTEXITCODE explicitly.
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
    Text = ($stdoutArr -join "`n").Trim()
    Error = ($stderrArr -join ' ').Trim()
    ExitCode = $exitCode
    Success = ($exitCode -eq 0)
  }
}

function Invoke-Az {
  param([Parameter(Mandatory)][string[]]$ArgumentList)
  Invoke-Native -FilePath 'az' -ArgumentList $ArgumentList
}

function ConvertTo-PlainText {
  param([System.Security.SecureString]$Secure)
  if (-not $Secure) { return '' }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
  try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# Reads a PFX purely to compare thumbprints - the key is never persisted
function Get-PfxThumbprint {
  param([string]$Path, [string]$Password)
  if (-not (Test-Path -LiteralPath $Path)) { return '' }
  try {
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $Path, $Password, $flags
    return $cert.Thumbprint
  } catch {
    return ''
  }
}

# ---- Ensuring log rotation --------------------------------------------------

Step 'Ensuring log rotation'

# ProgramData is readable by any authenticated user by default, and the log names
# every host and vault this machine touches
$acl = Invoke-Native -FilePath 'icacls' -ArgumentList @($LogDir, '/inheritance:r', '/grant:r', 'SYSTEM:(OI)(CI)F', 'BUILTIN\Administrators:(OI)(CI)F')
if (-not $acl.Success) { Warn "Could not restrict log directory permissions: $($acl.Error)" }

if ((Test-Path $LogFile) -and ((Get-Item $LogFile).LastWriteTime.Date -ne (Get-Date).Date)) {
  $archiveName = 'keyvault-cert-renewal-{0:yyyyMMdd}.log' -f (Get-Item $LogFile).LastWriteTime
  Rename-Item -Path $LogFile -NewName $archiveName -ErrorAction SilentlyContinue
}

Get-ChildItem -Path $LogDir -Filter 'keyvault-cert-renewal-*.log' -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
  Remove-Item -Force -ErrorAction SilentlyContinue

Success "Log rotation configured: $LogDir (30 days)"

# ---- Checking Azure CLI -----------------------------------------------------

Step 'Checking Azure CLI'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  Warn 'Azure CLI not found, installing...'
  $installer = Join-Path $env:TEMP 'AzureCLI.msi'
  Invoke-WebRequest -Uri 'https://aka.ms/installazurecliwindows' -OutFile $installer -UseBasicParsing

  # Verify the downloaded installer is genuinely signed by Microsoft before executing it
  $signature = Get-AuthenticodeSignature -FilePath $installer
  if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    Fail "Azure CLI installer failed signature verification (status: $($signature.Status)); refusing to run it"
  }

  $msiLog = Join-Path $env:TEMP 'AzureCLI-install.log'
  $proc = Start-Process msiexec.exe -ArgumentList @('/I', "`"$installer`"", '/quiet', '/norestart', '/L*V', "`"$msiLog`"") -Wait -PassThru
  Remove-Item $installer -Force -ErrorAction SilentlyContinue
  if ($proc.ExitCode -ne 0) {
    Fail "Azure CLI install failed with exit code $($proc.ExitCode). See $msiLog for details."
  }

  # msiexec updates the registry, not this process
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  Fail 'Azure CLI installation could not be verified. Install manually and re-run.'
}
$azVersion = Invoke-Az @('version', '--query', '"azure-cli"', '-o', 'tsv')
if ($azVersion.Success) { Success "Azure CLI Installed: $($azVersion.Text)" } else { Success 'Azure CLI Installed' }

# ---- Authenticating to Azure ------------------------------------------------

Step 'Authenticating to Azure'
if ($ClientId) {
  # Always re-login: a cached session may belong to a different identity on this VM.
  # --client-id replaced --username in newer Azure CLI releases, so try both.
  $login = Invoke-Az @('login', '--identity', '--client-id', $ClientId)
  if (-not $login.Success) {
    $login = Invoke-Az @('login', '--identity', '--username', $ClientId)
  }
  if (-not $login.Success) { Fail "az login --identity for $ClientId failed: $($login.Error)" }
  Info "Using user-assigned identity: $ClientId"
} elseif (-not (Invoke-Az @('account', 'show')).Success) {
  $login = Invoke-Az @('login', '--identity')
  if (-not $login.Success) { Fail "az login --identity failed: $($login.Error)" }
  Info 'Using system-assigned identity'
} else {
  Info 'Using existing Azure CLI session'
}
Success 'Authenticated to Azure'

# ---- Detecting web server ---------------------------------------------------

Step 'Detecting web server'
if (-not (Get-Service -Name W3SVC -ErrorAction SilentlyContinue)) {
  Fail 'IIS (W3SVC) is not installed on this host'
}
Import-Module WebAdministration -ErrorAction Stop
$w3svc = Get-Service -Name W3SVC
Success "Detected web server: IIS (W3SVC $($w3svc.Status))"

# With CCS, certificates are files named <hostname>.pfx on a share and bindings carry
# no thumbprint at all, so the install and verify paths are entirely different
$CcsPath = ''
$CcsPassword = ''
try {
  $ccsProvider = Get-WebCentralCertProvider -ErrorAction Stop
} catch {
  $ccsProvider = $null
}
if ($ccsProvider -and $ccsProvider.Enabled) {
  $CcsPath = $ccsProvider.CertStoreLocation
  if (-not $CentralCertStorePassword) {
    Fail "IIS Central Certificate Store is enabled ($CcsPath) - supply -CentralCertStorePassword so certificates can be written in the format CCS expects"
  }
  $CcsPassword = ConvertTo-PlainText $CentralCertStorePassword
  if (-not (Test-Path -LiteralPath $CcsPath)) {
    Fail "Central Certificate Store path is not reachable: $CcsPath"
  }
  Info "Central Certificate Store: $CcsPath"
} elseif ($CentralCertStorePassword) {
  Warn 'Central Certificate Store is not enabled - ignoring -CentralCertStorePassword'
}

# ---- Collecting server names ------------------------------------------------

Step 'Collecting server names'
# Http bindings are included too, so a site currently serving only http can still
# be given an https binding
$bindings = @()
foreach ($site in Get-Website) {
  foreach ($binding in $site.bindings.Collection) {
    $parts = $binding.bindingInformation -split ':'
    if ($parts.Count -lt 3) { continue }
    $hostHeader = $parts[2]
    if (-not $hostHeader -or $hostHeader -eq '*') { continue }
    $sslFlags = 0
    if ($null -ne $binding.sslFlags) { $sslFlags = [int]$binding.sslFlags }
    $bindings += [PSCustomObject]@{
      Site = $site.Name
      Protocol = $binding.protocol
      HostName = $hostHeader
      Ip = $parts[0]
      Port = $parts[1]
      SslFlags = $sslFlags
      Thumbprint = if ($binding.certificateHash) { [BitConverter]::ToString($binding.certificateHash).Replace('-', '') } else { '' }
    }
  }
}

$serverNames = @($bindings | Select-Object -ExpandProperty HostName -Unique | Sort-Object)
if ($serverNames.Count -eq 0) {
  Fail "No binding with a host name found in IIS. Add a host name to a site binding (e.g. 'example.com') and re-run."
}
Success "Found $($serverNames.Count) server name(s)"
$serverNames | ForEach-Object { Info "- $_" }

# ---- Locating Key Vault -----------------------------------------------------

Step 'Locating Key Vault'
if ($KeyVaultName) {
  Info 'Using manual override'
} else {
  $vaultResult = Invoke-Az @('keyvault', 'list', '--query', '[].name', '-o', 'tsv')
  if (-not $vaultResult.Success) { Fail "az keyvault list failed: $($vaultResult.Error)" }
  $vaults = @($vaultResult.Output | Where-Object { $_ })
  if ($vaults.Count -eq 0) { Fail 'No Key Vault accessible to this managed identity' }
  if ($vaults.Count -gt 1) { Fail "Expected exactly one accessible Key Vault, found $($vaults.Count): $($vaults -join ', ')" }
  $KeyVaultName = $vaults[0]
}
Success "Using Key Vault: $KeyVaultName"

# ---- Matching certificates --------------------------------------------------

Step 'Matching certificates'
$matched = @{}
foreach ($hostName in $serverNames) {
  # Rejects anything that is not a plain host name
  if ($hostName -notmatch '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$') {
    Warn "Skipping malformed server name: $hostName"
    continue
  }

  # Key Vault names cannot contain dots, so site.example.com is stored as site-example-com
  $certName = $hostName.Replace('.', '-')

  # Reads only the public certificate (cer) - no secret access, no local changes
  $cerResult = Invoke-Az @('keyvault', 'certificate', 'show', '--vault-name', $KeyVaultName, '--name', $certName, '--query', 'cer', '-o', 'tsv')
  if (-not $cerResult.Success) {
    # if/elseif rather than switch: continue inside a switch would only advance the
    # switch, not this foreach
    $azError = $cerResult.Error
    if ($azError -match 'CERTIFICATE_VERIFY_FAILED|SSLError|certificate verify failed') {
      $resolved = (Resolve-DnsName "$KeyVaultName.vault.azure.net" -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress } | Select-Object -ExpandProperty IPAddress) -join ' '
      Info "$KeyVaultName.vault.azure.net resolves to: $resolved"
      Fail "TLS validation failed reaching $KeyVaultName.vault.azure.net - check private endpoint DNS or an intercepting proxy: $azError"
    } elseif ($azError -match 'Forbidden|AccessDenied|not authorized|does not have') {
      Fail "Access denied reading '$certName' - grant the identity get on certificates and secrets: $azError"
    } elseif ($azError -match 'NotFound|not found|CertificateNotFound') {
      Warn "${hostName}: no certificate named '$certName' in $KeyVaultName"
      continue
    } else {
      Warn "${hostName}: could not read '$certName': $azError"
      continue
    }
  }
  if (-not $cerResult.Text) {
    Warn "${hostName}: certificate '$certName' returned no public certificate (cer) data"
    continue
  }

  $vaultCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($cerResult.Text))
  $expiryDays = [int]([TimeSpan]($vaultCert.NotAfter - (Get-Date))).TotalDays
  if ($expiryDays -lt 0) { Warn "Certificate '$certName' has already expired" }

  $matched[$hostName] = [PSCustomObject]@{
    CertName = $certName
    Thumbprint = $vaultCert.Thumbprint
    NotAfter = $vaultCert.NotAfter
    Days = $expiryDays
  }
  Info $hostName
  Detail "$certName, expires $($vaultCert.NotAfter.ToString('yyyy-MM-dd')) ($expiryDays days)"
}

if ($matched.Count -eq 0) {
  Fail "No certificate in $KeyVaultName matches: $($serverNames -join ', ')"
}
Success "Matched $($matched.Count) of $($serverNames.Count) host(s)"

# ---- Checking certificate status --------------------------------------------

Step 'Checking certificate status'
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store 'My', 'LocalMachine'
$store.Open('ReadOnly')
$installedThumbprints = @($store.Certificates | ForEach-Object { $_.Thumbprint })
$store.Close()

$staleHosts = @()
foreach ($hostName in ($matched.Keys | Sort-Object)) {
  $wanted = $matched[$hostName]
  $httpsBinding = $bindings | Where-Object { $_.HostName -eq $hostName -and $_.Protocol -eq 'https' } | Select-Object -First 1

  if ($CcsPath) {
    # CCS bindings carry no thumbprint - the certificate is the file, and the binding
    # only has to be flagged to look there
    $present = (Get-PfxThumbprint (Join-Path $CcsPath "$hostName.pfx") $CcsPassword) -eq $wanted.Thumbprint
    $bound = ($httpsBinding -and (($httpsBinding.SslFlags -band $SslFlagCcs) -eq $SslFlagCcs))
  } else {
    $present = $installedThumbprints -contains $wanted.Thumbprint
    $bound = ($httpsBinding -and $httpsBinding.Thumbprint -eq $wanted.Thumbprint)
  }

  if ($bound -and $present) {
    Info "${hostName}: up to date"
    # An up-to-date copy of a near-expiry certificate means the ACME issuance side
    # has not renewed it yet, which this script cannot fix
    if ($wanted.Days -le $ExpiryWarningDays) {
      Warn "$hostName expires in $($wanted.Days) days - check the ACME renewal job"
    }
  } else {
    $staleHosts += $hostName
    Info "${hostName}: needs update"
  }
}
Success "$($staleHosts.Count) of $($matched.Count) host(s) need a new certificate"

if ($staleHosts.Count -eq 0) {
  Step 'Done'
  Success 'All certificates and IIS bindings are already up to date, nothing to do.'
  exit 0
}

if ($DryRun) {
  foreach ($hostName in $staleHosts) {
    if ($CcsPath) {
      Warn "Dry run: $($matched[$hostName].CertName) would be written to $(Join-Path $CcsPath "$hostName.pfx")"
    } else {
      Warn "Dry run: $($matched[$hostName].CertName) would be installed and bound to $hostName"
    }
  }
  Step 'Done'
  Success 'Dry run complete, nothing was changed'
  exit 0
}

# ---- Downloading certificates -----------------------------------------------

Step 'Downloading certificates'
# Keyed by certificate name, so one shared by several bindings costs a single secret read
$downloaded = @{}
foreach ($hostName in $staleHosts) {
  $wanted = $matched[$hostName]
  if ($downloaded.ContainsKey($wanted.CertName)) { continue }

  # Certificates are stored as PFX-encoded secrets alongside the certificate object
  $secretResult = Invoke-Az @('keyvault', 'secret', 'show', '--vault-name', $KeyVaultName, '--name', $wanted.CertName, '--query', 'value', '-o', 'tsv')
  if (-not $secretResult.Success) {
    Fail "Failed to read secret '$($wanted.CertName)' from Key Vault '$KeyVaultName': $($secretResult.Error)"
  }
  if (-not $secretResult.Text) { Fail "Secret '$($wanted.CertName)' is empty" }

  $downloaded[$wanted.CertName] = [Convert]::FromBase64String($secretResult.Text)
  $secretResult = $null
  Info "Downloaded: $($wanted.CertName)"
}
Success "Downloaded $($downloaded.Count) certificate(s) into memory"

# ---- Installing certificates ------------------------------------------------

Step 'Installing certificates'
$backupDir = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMddHHmmss')
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# applicationHost.config carries every binding, so one copy covers rollback of all of them
$appHostConfig = Join-Path $env:windir 'system32\inetsrv\config\applicationHost.config'
Copy-Item -Path $appHostConfig -Destination (Join-Path $backupDir 'applicationHost.config') -Force
Info "applicationHost.config backed up to $backupDir"

# Tracked so a rollback undoes exactly what this run did, and no more
$importedThumbprints = @()
$writtenCcsFiles = @()
$backedUpCcsFiles = @()

try {
  if ($CcsPath) {
    foreach ($hostName in $staleHosts) {
      $wanted = $matched[$hostName]
      $target = Join-Path $CcsPath "$hostName.pfx"

      if (Test-Path -LiteralPath $target) {
        $backupCopy = Join-Path $backupDir "$hostName.pfx"
        Copy-Item -LiteralPath $target -Destination $backupCopy -Force
        $backedUpCcsFiles += [PSCustomObject]@{ Target = $target; Backup = $backupCopy }
      }

      # EphemeralKeySet keeps the key out of any machine key container - it exists only
      # for the moment needed to re-encrypt under the CCS password
      $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable -bor
      [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
      $collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
      try {
        $collection.Import($downloaded[$wanted.CertName], $null, $flags)
      } catch {
        Fail "Could not import PFX for $($wanted.CertName): $($_.Exception.Message)"
      }

      $leaf = $collection | Where-Object { $_.HasPrivateKey } | Select-Object -First 1
      if (-not $leaf) { Fail "PFX for $($wanted.CertName) contains no private key" }
      if ($leaf.Thumbprint -ne $wanted.Thumbprint) {
        Fail "Downloaded $($wanted.CertName) thumbprint ($($leaf.Thumbprint)) does not match Key Vault ($($wanted.Thumbprint))"
      }

      # CCS requires every PFX in the share to be encrypted with the provider password
      $reEncrypted = $collection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $CcsPassword)
      try {
        # Written via a temp name and moved, so IIS never sees a half-written file
        $temp = "$target.tmp"
        [System.IO.File]::WriteAllBytes($temp, $reEncrypted)
        Move-Item -LiteralPath $temp -Destination $target -Force
        $writtenCcsFiles += $target
      } finally {
        [Array]::Clear($reEncrypted, 0, $reEncrypted.Length)
      }

      Info $hostName
      Detail "$target ($($wanted.Thumbprint))"
    }
    Success "Wrote $($writtenCcsFiles.Count) certificate(s) to the Central Certificate Store"
  } else {
    $myStore = New-Object System.Security.Cryptography.X509Certificates.X509Store 'My', 'LocalMachine'
    $myStore.Open('ReadWrite')
    $caStore = New-Object System.Security.Cryptography.X509Certificates.X509Store 'CA', 'LocalMachine'
    $caStore.Open('ReadWrite')
    try {
      foreach ($certName in @($downloaded.Keys)) {
        $expected = ($matched.Values | Where-Object { $_.CertName -eq $certName } | Select-Object -First 1).Thumbprint
        if ($installedThumbprints -contains $expected) {
          Info $certName
          Detail 'already in LocalMachine\My'
          continue
        }

        # MachineKeySet so IIS (running as a service) can use the key, PersistKeySet so it
        # survives past this process. Never marked Exportable - the key only needs to be
        # usable, not extractable, and this way it is never written to disk in the clear.
        $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
        $collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        try {
          $collection.Import($downloaded[$certName], $null, $flags)
        } catch {
          Fail "Could not import PFX for ${certName}: $($_.Exception.Message)"
        }

        $leaf = $collection | Where-Object { $_.HasPrivateKey } | Select-Object -First 1
        if (-not $leaf) { Fail "PFX for $certName contains no private key" }
        if ($leaf.Thumbprint -ne $expected) {
          Fail "Imported $certName thumbprint ($($leaf.Thumbprint)) does not match Key Vault ($expected)"
        }

        $myStore.Add($leaf)
        $importedThumbprints += $leaf.Thumbprint

        # Intermediates go to the CA store so clients receive a complete chain
        foreach ($chainCert in ($collection | Where-Object { -not $_.HasPrivateKey })) {
          if ($chainCert.Subject -ne $chainCert.Issuer) { $caStore.Add($chainCert) }
        }

        Info $certName
        Detail "thumbprint $($leaf.Thumbprint)"
      }
    } finally {
      $myStore.Close()
      $caStore.Close()
    }
    Success "Installed $($importedThumbprints.Count) certificate(s) into LocalMachine\My"
  }
} finally {
  # The decoded PFX must not outlive the install step
  foreach ($certName in @($downloaded.Keys)) {
    if ($downloaded[$certName]) {
      [Array]::Clear($downloaded[$certName], 0, $downloaded[$certName].Length)
      $downloaded[$certName] = $null
    }
  }
}

# ---- Applying IIS bindings --------------------------------------------------

Step 'Applying IIS bindings'

function Invoke-Rollback {
  Warn 'Rolling back bindings and certificates'
  Copy-Item -Path (Join-Path $backupDir 'applicationHost.config') -Destination $appHostConfig -Force -ErrorAction SilentlyContinue

  foreach ($entry in $backedUpCcsFiles) {
    Copy-Item -LiteralPath $entry.Backup -Destination $entry.Target -Force -ErrorAction SilentlyContinue
  }
  # A file this run created has no previous version to restore, so remove it
  foreach ($file in $writtenCcsFiles) {
    if (-not ($backedUpCcsFiles | Where-Object { $_.Target -eq $file })) {
      Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
  }

  if ($importedThumbprints.Count -gt 0) {
    $rollbackStore = New-Object System.Security.Cryptography.X509Certificates.X509Store 'My', 'LocalMachine'
    $rollbackStore.Open('ReadWrite')
    foreach ($thumb in $importedThumbprints) {
      $cert = $rollbackStore.Certificates | Where-Object { $_.Thumbprint -eq $thumb }
      if ($cert) { $rollbackStore.Remove($cert) }
    }
    $rollbackStore.Close()
  }
}

$replaced = @()
foreach ($hostName in $staleHosts) {
  $wanted = $matched[$hostName]
  $existing = $bindings | Where-Object { $_.HostName -eq $hostName -and $_.Protocol -eq 'https' } | Select-Object -First 1

  try {
    if (-not $existing) {
      if ($NoBindingCreate) {
        Warn "$hostName has no https binding and -NoBindingCreate was set - skipping"
        continue
      }
      $site = ($bindings | Where-Object { $_.HostName -eq $hostName } | Select-Object -First 1).Site
      # SNI lets several host names share port 443; CCS additionally tells IIS to
      # resolve the certificate from the store share by host name
      $newFlags = if ($CcsPath) { $SslFlagSni -bor $SslFlagCcs } else { $SslFlagSni }
      New-WebBinding -Name $site -Protocol https -Port 443 -HostHeader $hostName -SslFlags $newFlags
      Info $hostName
      Detail "https binding created on $site"
    } else {
      $replaced += $existing.Thumbprint
      Info $hostName
    }

    if ($CcsPath) {
      # The certificate is the file; the binding only needs the CCS flag set
      if ($existing -and (($existing.SslFlags -band $SslFlagCcs) -ne $SslFlagCcs)) {
        Set-WebBinding -Name $existing.Site -BindingInformation "$($existing.Ip):$($existing.Port):$hostName" `
          -PropertyName sslFlags -Value ($existing.SslFlags -bor $SslFlagCcs -bor $SslFlagSni)
        Detail 'binding switched to the Central Certificate Store'
      } else {
        Detail 'certificate file updated'
      }
    } else {
      # SNI (host-header) bindings store their certificate mapping in applicationHost.config
      # via the binding's own AddSslCertificate method - not in netsh's HTTP.SYS store,
      # which IIS Manager's "SSL certificate" dropdown does not read for these bindings.
      $webBinding = Get-WebBinding -Protocol https -HostHeader $hostName | Select-Object -First 1
      $webBinding.AddSslCertificate($wanted.Thumbprint, 'my')
      Detail 'certificate bound'
    }
  } catch {
    Invoke-Rollback
    Fail "Failed to bind certificate for ${hostName}: $($_.Exception.Message)"
  }
}

# The binding is the thing that actually has to be right, so read it back rather
# than trusting that the change succeeded
foreach ($hostName in $staleHosts) {
  $wanted = $matched[$hostName]
  $check = Get-WebBinding -Protocol https -HostHeader $hostName | Select-Object -First 1
  if (-not $check) { Invoke-Rollback; Fail "No https binding present for $hostName after applying" }

  if ($CcsPath) {
    $flags = if ($null -ne $check.sslFlags) { [int]$check.sslFlags } else { 0 }
    if (($flags -band $SslFlagCcs) -ne $SslFlagCcs) {
      Invoke-Rollback
      Fail "Binding for $hostName is not flagged for the Central Certificate Store (sslFlags $flags)"
    }
    $onDisk = Get-PfxThumbprint (Join-Path $CcsPath "$hostName.pfx") $CcsPassword
    if ($onDisk -ne $wanted.Thumbprint) {
      Invoke-Rollback
      Fail "Central Certificate Store file for $hostName reports thumbprint '$onDisk', expected '$($wanted.Thumbprint)'"
    }
  } else {
    $actual = if ($check.certificateHash) { [BitConverter]::ToString($check.certificateHash).Replace('-', '') } else { '' }
    if ($actual -ne $wanted.Thumbprint) {
      Invoke-Rollback
      Fail "Binding for $hostName reports thumbprint '$actual', expected '$($wanted.Thumbprint)'"
    }
  }
}
Success 'Bindings applied and verified'

# ---- Reloading IIS ----------------------------------------------------------

Step 'Reloading IIS'
if ($w3svc.Status -ne 'Running') {
  Warn 'W3SVC is not running, skipping reload - bindings are set and will apply on next start'
} elseif ($RestartIis) {
  $reset = Invoke-Native -FilePath 'iisreset' -ArgumentList @('/noforce')
  if (-not $reset.Success) { Invoke-Rollback; Fail "iisreset failed: $($reset.Error)" }
  Success 'IIS restarted'
} else {
  # Binding certificate changes are picked up by HTTP.SYS immediately; a restart is
  # only needed for sites that cache the certificate in-process
  Success 'Bindings live, no restart required (use -RestartIis to force one)'
}

# Superseded certificates are removed only once the new binding is confirmed live,
# and only when nothing else on this machine still references them
if (-not $CcsPath -and $replaced.Count -gt 0) {
  $myStore = New-Object System.Security.Cryptography.X509Certificates.X509Store 'My', 'LocalMachine'
  $myStore.Open('ReadWrite')
  $stillBound = @(Get-WebBinding -Protocol https | ForEach-Object {
      if ($_.certificateHash) { [BitConverter]::ToString($_.certificateHash).Replace('-', '') }
    })
  foreach ($thumb in ($replaced | Select-Object -Unique)) {
    if (-not $thumb -or $stillBound -contains $thumb -or $importedThumbprints -contains $thumb) { continue }
    $old = $myStore.Certificates | Where-Object { $_.Thumbprint -eq $thumb }
    if ($old) {
      $myStore.Remove($old)
      Info "Removed superseded certificate $thumb"
    }
  }
  $myStore.Close()
}

# A backed-up CCS file is a private key in a password-protected container - useful for
# rollback during the run, not something to leave lying around for 30 days afterwards
foreach ($entry in $backedUpCcsFiles) {
  Remove-Item -LiteralPath $entry.Backup -Force -ErrorAction SilentlyContinue
}

Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# ---- Summary ----------------------------------------------------------------

Step 'Done'
Info "Key Vault   $KeyVaultName"
if ($CcsPath) { Info "Web server  IIS (Central Certificate Store)" } else { Info 'Web server  IIS' }
Info "Log         $LogFile"
foreach ($hostName in ($matched.Keys | Sort-Object)) {
  $entry = $matched[$hostName]
  Write-Host ''
  Info $hostName
  Detail "certificate  $($entry.CertName)"
  if ($CcsPath) { Detail "installed    $(Join-Path $CcsPath "$hostName.pfx")" }
  Detail "thumbprint   $($entry.Thumbprint)"
  Detail "expires      $($entry.NotAfter.ToString('yyyy-MM-dd')) ($($entry.Days) days)"
}
Write-Host ''
Success "Updated $($staleHosts.Count) host(s), IIS bindings verified"

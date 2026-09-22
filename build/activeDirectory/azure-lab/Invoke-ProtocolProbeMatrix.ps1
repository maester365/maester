<#
.SYNOPSIS
    Executes the mandatory LDAP protocol probe matrix on an AD lab runner.

.DESCRIPTION
    Runs protocol-level LDAP binds that cannot be certified by the public AD
    test suite alone. Every selected row writes a machine-readable JSON artifact.
    The process exits non-zero if an actual bind outcome differs from the row's
    expected outcome.

.PARAMETER Runner
    Runner whose platform and identity are being exercised.

.PARAMETER Target
    Optional matrix filter for DC02, DC03, or DC04.

.PARAMETER TargetingMode
    Optional matrix filter for ambient (Implicit) or server (Explicit) targeting.

.PARAMETER CredentialMode
    Optional matrix filter for ambient (Implicit) or supplied (Explicit) credentials.

.PARAMETER AuthMode
    Optional matrix filter for Negotiate or Basic authentication.

.PARAMETER TlsMode
    Optional matrix filter for LDAPS, StartTLS, or no TLS.

.PARAMETER Credential
    Explicit credential override for a single-target invocation.

.PARAMETER RootCredential
    Explicit misoule02.local credential used by DC02 rows.

.PARAMETER ChildCredential
    Explicit child.misoule02.local credential used by DC03 rows.

.PARAMETER SeparateForestCredential
    Explicit misoule03.local credential used by DC04 rows.

.EXAMPLE
    ./Invoke-ProtocolProbeMatrix.ps1 -Runner Windows -RootCredential $rootCredential `
        -ChildCredential $childCredential -SeparateForestCredential $forestCredential

    Runs all Windows rows.

.EXAMPLE
    ./Invoke-ProtocolProbeMatrix.ps1 -Runner Linux -Target DC02 -TargetingMode Explicit `
        -CredentialMode Explicit -AuthMode Basic -TlsMode StartTls -Credential $rootCredential

    Runs the Linux Basic-over-StartTLS row for DC02.
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Runner script reports row progress while JSON files provide machine-readable output.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    '',
    Justification = 'CredentialMode and ProbeCredential are mode/object parameters; no parameter accepts a plaintext password.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Credential parameters are selected by Get-ProbeCredential; ScriptAnalyzer does not resolve the script-scope closure.'
)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Windows', 'Linux')]
    [string]$Runner,

    [Parameter()]
    [ValidateSet('DC02', 'DC03', 'DC04')]
    [string]$Target,

    [Parameter()]
    [ValidateSet('Implicit', 'Explicit')]
    [string]$TargetingMode,

    [Parameter()]
    [ValidateSet('Implicit', 'Explicit')]
    [string]$CredentialMode,

    [Parameter()]
    [ValidateSet('Negotiate', 'Basic')]
    [string]$AuthMode,

    [Parameter()]
    [ValidateSet('Ldaps', 'StartTls', 'None')]
    [string]$TlsMode,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [System.Management.Automation.PSCredential]$RootCredential,

    [Parameter()]
    [System.Management.Automation.PSCredential]$ChildCredential,

    [Parameter()]
    [System.Management.Automation.PSCredential]$SeparateForestCredential,

    [Parameter()]
    [string]$MaesterModulePath = (Join-Path $PSScriptRoot '..\..\..\powershell'),

    [Parameter()]
    [string]$EvidencePath = (Join-Path $PSScriptRoot 'evidence')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RedactedProbeError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    $message = [string]$Exception.Message
    $message = $message -replace '(?i)(ldap(?:s)?://)?[^/\s:@]+:[^@\s/]+@', '$1<redacted>@'
    $message = $message -replace '(?i)(password|pwd|passphrase)\s*[=:]\s*[^\s;,]+', '$1=<redacted>'

    if ($null -ne $Credential -and -not [string]::IsNullOrWhiteSpace($Credential.UserName)) {
        $message = $message -replace [regex]::Escape($Credential.UserName), '<redacted-user>'
    }

    if ([string]::IsNullOrWhiteSpace($message)) {
        return 'LDAP probe failed without an error message.'
    }

    return $message
}

function Get-ProbeCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Target
    )

    $selectedCredential = $null
    if ($null -ne $Credential) {
        $selectedCredential = $Credential
    }
    else {
        $selectedCredential = switch ($Target) {
            'DC02' { $RootCredential }
            'DC03' { $ChildCredential }
            'DC04' { $SeparateForestCredential }
        }
    }

    if ($null -eq $selectedCredential) {
        return $null
    }

    $userName = $selectedCredential.UserName
    $credentialDomain = $null
    if ($userName -match '^(?<Domain>[^\\]+)\\[^\\]+$') {
        $credentialDomain = $Matches.Domain
    }
    elseif ($userName -match '^[^@]+@(?<Domain>[^@]+)$') {
        $credentialDomain = $Matches.Domain
    }

    if ([string]::IsNullOrWhiteSpace($credentialDomain) -or $targetDefinitions[$Target].CredentialDomains -notcontains $credentialDomain) {
        throw "The supplied credential is not qualified for $Target's directory. Refusing a cross-directory bind."
    }

    return $selectedCredential
}

function Write-ProbeJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $json = $InputObject | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Test-ProbeTcpPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HostName,

        [Parameter(Mandatory)]
        [int]$Port,

        [timespan]$Timeout = [timespan]::FromSeconds(5)
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        return $task.Wait($Timeout) -and $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Write-MergedProbeSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$NewRows
    )

    if ($NewRows.Count -eq 0) {
        return
    }

    $rowsById = [ordered]@{}
    if (Test-Path -LiteralPath $Path) {
        try {
            $existing = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
            if ($existing.LiveProbeExecution -eq $true) {
                foreach ($existingRow in @($existing.Rows)) {
                    $rowsById[$existingRow.ProbeId] = $existingRow
                }
            }
        }
        catch {
            Write-Verbose "Ignoring an incompatible prior summary at '$Path'."
        }
    }

    foreach ($newRow in $NewRows) {
        $rowsById[$newRow.ProbeId] = $newRow
    }

    $summaryRows = @($rowsById.Values)
    $summaryContainsBind = @($summaryRows | Where-Object FinalBindOutcome -eq Bound).Count -gt 0
    $summary = [ordered]@{
        SchemaVersion       = 1
        RecordedAt          = [datetime]::UtcNow.ToString('o')
        LiveProbeExecution  = $true
        LiveDirectoryBind   = $summaryContainsBind
        Runners             = @($summaryRows | ForEach-Object { $_.Runner } | Sort-Object -Unique)
        AllExpectationsMet  = @($summaryRows | Where-Object { -not $_.ExpectationMet }).Count -eq 0
        Rows                = $summaryRows
    }
    Write-ProbeJson -InputObject $summary -Path $Path
}

$targetDefinitions = @{
    DC02 = [ordered]@{
        Fqdn              = 'MiSouleDC02.misoule02.local'
        Ip                = '10.20.0.4'
        Domain            = 'misoule02.local'
        Forest            = 'misoule02.local'
        CredentialDomains = @('MISOULE02', 'misoule02.local')
    }
    DC03 = [ordered]@{
        Fqdn              = 'MiSouleDC03.child.misoule02.local'
        Ip                = '10.20.0.5'
        Domain            = 'child.misoule02.local'
        Forest            = 'misoule02.local'
        CredentialDomains = @('CHILD', 'child.misoule02.local')
    }
    DC04 = [ordered]@{
        Fqdn              = 'MiSouleDC04.misoule03.local'
        Ip                = '10.20.0.6'
        Domain            = 'misoule03.local'
        Forest            = 'misoule03.local'
        CredentialDomains = @('MISOULE03', 'misoule03.local')
    }
}

function Get-ProbeRow {
    param(
        [string]$Id,
        [string]$Runner,
        [string]$Target,
        [string]$TargetingMode,
        [string]$CredentialMode,
        [string]$AuthMode,
        [string]$TlsMode,
        [string]$ExpectedOutcome,
        [string]$ExpectedErrorPattern = $null,
        [string]$FailureCondition = $null
    )

    [PSCustomObject]@{
        Id                   = $Id
        Runner               = $Runner
        Target               = $Target
        TargetingMode        = $TargetingMode
        CredentialMode       = $CredentialMode
        AuthMode             = $AuthMode
        TlsMode              = $TlsMode
        ExpectedOutcome      = $ExpectedOutcome
        ExpectedErrorPattern = $ExpectedErrorPattern
        FailureCondition     = $FailureCondition
    }
}

# The first thirteen rows are the approved matrix (twelve positive and the
# Basic-without-TLS negative). The final three rows prove no-trust and broken-
# certificate failure contracts explicitly.
$matrix = @(
    Get-ProbeRow -Id 'win-dc02-implicit-implicit-negotiate-ldaps' -Runner Windows -Target DC02 -TargetingMode Implicit -CredentialMode Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'win-dc02-implicit-explicit-negotiate-ldaps' -Runner Windows -Target DC02 -TargetingMode Implicit -CredentialMode Explicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'win-dc02-explicit-implicit-negotiate-ldaps' -Runner Windows -Target DC02 -TargetingMode Explicit -CredentialMode Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'win-dc02-explicit-explicit-basic-ldaps' -Runner Windows -Target DC02 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'win-dc03-explicit-implicit-negotiate-ldaps' -Runner Windows -Target DC03 -TargetingMode Explicit -CredentialMode Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'win-dc03-explicit-explicit-basic-ldaps' -Runner Windows -Target DC03 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'win-dc04-explicit-explicit-basic-ldaps' -Runner Windows -Target DC04 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'linux-dc02-explicit-explicit-basic-ldaps' -Runner Linux -Target DC02 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'linux-dc03-explicit-explicit-basic-ldaps' -Runner Linux -Target DC03 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'linux-dc04-explicit-explicit-basic-ldaps' -Runner Linux -Target DC04 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-ProbeRow -Id 'win-dc02-explicit-explicit-basic-none' -Runner Windows -Target DC02 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Basic -TlsMode None -ExpectedOutcome FAIL -ExpectedErrorPattern '^Basic authentication requires LDAPS on port 636 or StartTLS\.$' -FailureCondition BasicWithoutTls
    Get-ProbeRow -Id 'win-dc02-implicit-implicit-negotiate-starttls' -Runner Windows -Target DC02 -TargetingMode Implicit -CredentialMode Implicit -AuthMode Negotiate -TlsMode StartTls -ExpectedOutcome PASS
    Get-ProbeRow -Id 'linux-dc02-explicit-explicit-basic-starttls' -Runner Linux -Target DC02 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Basic -TlsMode StartTls -ExpectedOutcome PASS
    Get-ProbeRow -Id 'win-dc04-explicit-implicit-negotiate-ldaps-no-trust' -Runner Windows -Target DC04 -TargetingMode Explicit -CredentialMode Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome FAIL -ExpectedErrorPattern '(?i)(authentication|credential|logon|user name or password)' -FailureCondition NoForestTrust
    Get-ProbeRow -Id 'win-dc02-explicit-explicit-negotiate-starttls-broken-cert' -Runner Windows -Target DC02 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Negotiate -TlsMode StartTls -ExpectedOutcome FAIL -ExpectedErrorPattern '(?i)(certificate|TLS|SSL|LDAP server is unavailable)' -FailureCondition CertificateNameMismatch
    Get-ProbeRow -Id 'linux-dc02-explicit-explicit-negotiate-starttls-broken-cert' -Runner Linux -Target DC02 -TargetingMode Explicit -CredentialMode Explicit -AuthMode Negotiate -TlsMode StartTls -ExpectedOutcome FAIL -ExpectedErrorPattern '(?i)(certificate|TLS|SSL|LDAP server is unavailable)' -FailureCondition CertificateNameMismatch
)

$actualPlatform = if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) { 'Windows' } else { 'Linux' }
if ($actualPlatform -ne $Runner) {
    throw "Runner '$Runner' does not match the current PowerShell platform '$actualPlatform'."
}

if ($null -ne $Credential -and [string]::IsNullOrWhiteSpace($Target)) {
    throw 'The generic -Credential override requires -Target so it cannot be reused across directory boundaries.'
}

$selectedRows = @($matrix | Where-Object {
        $_.Runner -eq $Runner -and
        ([string]::IsNullOrWhiteSpace($Target) -or $_.Target -eq $Target) -and
        ([string]::IsNullOrWhiteSpace($TargetingMode) -or $_.TargetingMode -eq $TargetingMode) -and
        ([string]::IsNullOrWhiteSpace($CredentialMode) -or $_.CredentialMode -eq $CredentialMode) -and
        ([string]::IsNullOrWhiteSpace($AuthMode) -or $_.AuthMode -eq $AuthMode) -and
        ([string]::IsNullOrWhiteSpace($TlsMode) -or $_.TlsMode -eq $TlsMode)
    })

if ($selectedRows.Count -eq 0) {
    throw 'The supplied filters do not match an approved protocol probe row.'
}

if (-not (Test-Path -LiteralPath $EvidencePath)) {
    New-Item -Path $EvidencePath -ItemType Directory -Force | Out-Null
}
$EvidencePath = (Resolve-Path -LiteralPath $EvidencePath -ErrorAction Stop).Path

$MaesterModulePath = (Resolve-Path -LiteralPath $MaesterModulePath -ErrorAction Stop).Path
$manifestPath = Join-Path $MaesterModulePath 'Maester.psd1'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Maester module manifest not found at '$manifestPath'."
}
$maesterModule = Import-Module $manifestPath -Force -PassThru

$results = [System.Collections.Generic.List[object]]::new()
foreach ($row in $selectedRows) {
    $definition = $targetDefinitions[$row.Target]
    $rowCredential = if ($row.CredentialMode -eq 'Explicit') { Get-ProbeCredential -Target $row.Target } else { $null }
    $requestedTarget = if ($row.TargetingMode -eq 'Explicit') { $definition.Fqdn } else { $null }
    $connectionTarget = if ($row.FailureCondition -eq 'CertificateNameMismatch') { $definition.Ip } else { $definition.Fqdn }
    $resolvedTarget = $null
    $resolvedDomain = $null
    $resolvedForest = $null
    $selectedTlsMode = $null
    $bindResult = 'NotAttempted'
    $actualOutcome = 'FAIL'
    $errorMessage = $null
    $probeInvoked = $false
    $controlBindSucceeded = $null
    $controlResolvedTarget = $null

    Write-Host "Running $($row.Id)..." -ForegroundColor Cyan
    try {
        if ($row.CredentialMode -eq 'Explicit' -and $null -eq $rowCredential) {
            throw "Explicit credential mode requires a credential for $($row.Target)."
        }

        if ($row.FailureCondition -in @('CertificateNameMismatch', 'NoForestTrust')) {
            $probePort = if ($row.TlsMode -eq 'Ldaps') { 636 } else { 389 }
            if (-not (Test-ProbeTcpPort -HostName $connectionTarget -Port $probePort)) {
                throw "Probe prerequisite failed: $connectionTarget TCP/$probePort is unreachable."
            }
        }

        if ($row.FailureCondition -eq 'CertificateNameMismatch') {
            $controlParameters = @{
                ActiveDirectoryServer     = $definition.Fqdn
                ActiveDirectoryCredential = $rowCredential
                AuthMode                   = $row.AuthMode
                TlsMode                    = $row.TlsMode
            }
            $controlState = & $maesterModule {
                param($Parameters)

                try {
                    Connect-MtAdTarget @Parameters
                    return [PSCustomObject]$__MtSession.ADConnection
                }
                finally {
                    $__MtSession.ADCredential = $null
                }
            } $controlParameters
            if (-not $controlState.Connected -or -not $controlState.ProtocolValidated) {
                throw 'The trusted-FQDN control bind did not complete successfully.'
            }
            if ($controlState.ResolvedDomain -ne $definition.Domain -or $controlState.ResolvedForest -ne $definition.Forest) {
                throw 'The trusted-FQDN control bind resolved to the wrong directory.'
            }
            $controlBindSucceeded = $true
            $controlResolvedTarget = $controlState.ResolvedServer

            $probeInvoked = $true
            $directResult = & $maesterModule {
                param($Server, $ProbeCredential, $ProbeAuthMode)

                $connection = $null
                try {
                    $parameters = @{
                        Server      = $Server
                        Port        = 389
                        UseStartTls = $true
                        AuthType    = $ProbeAuthMode
                        Credential  = $ProbeCredential
                    }
                    $connection = New-MtLdapConnection @parameters
                    $rootDse = Get-MtLdapRootDse -Connection $connection
                    [PSCustomObject]@{
                        ResolvedServer = [string]$rootDse.DnsHostName
                    }
                }
                finally {
                    if ($null -ne $connection) {
                        $connection.Dispose()
                    }
                }
            } $connectionTarget $rowCredential $row.AuthMode
            $resolvedTarget = $directResult.ResolvedServer
            $selectedTlsMode = 'StartTls'
        }
        elseif ($row.TlsMode -eq 'None') {
            $probeInvoked = $true
            $directResult = & $maesterModule {
                param($Server, $ProbeCredential, $ProbeAuthMode)

                $connection = $null
                try {
                    $parameters = @{
                        Server   = $Server
                        Port     = 389
                        AuthType = $ProbeAuthMode
                    }
                    if ($null -ne $ProbeCredential) {
                        $parameters.Credential = $ProbeCredential
                    }
                    $connection = New-MtLdapConnection @parameters
                    $rootDse = Get-MtLdapRootDse -Connection $connection
                    [PSCustomObject]@{
                        ResolvedServer = [string]$rootDse.DnsHostName
                        ResolvedDomain = [string]$rootDse.DefaultNamingContext
                    }
                }
                finally {
                    if ($null -ne $connection) {
                        $connection.Dispose()
                    }
                }
            } $connectionTarget $rowCredential $row.AuthMode

            $resolvedTarget = $directResult.ResolvedServer
            $resolvedDomain = $directResult.ResolvedDomain
            $selectedTlsMode = 'None'
        }
        else {
            $connectionParameters = @{
                AuthMode = $row.AuthMode
                TlsMode  = $row.TlsMode
            }
            if ($row.TargetingMode -eq 'Explicit') {
                $connectionParameters.ActiveDirectoryServer = $connectionTarget
            }
            if ($null -ne $rowCredential) {
                $connectionParameters.ActiveDirectoryCredential = $rowCredential
            }

            $probeInvoked = $true
            $connectionState = & $maesterModule {
                param($Parameters)

                try {
                    Connect-MtAdTarget @Parameters
                    return [PSCustomObject]$__MtSession.ADConnection
                }
                finally {
                    $__MtSession.ADCredential = $null
                }
            } $connectionParameters

            if (-not $connectionState.Connected -or -not $connectionState.ProtocolValidated) {
                throw 'The LDAP protocol path returned without a validated bind.'
            }
            $resolvedTarget = $connectionState.ResolvedServer
            $resolvedDomain = $connectionState.ResolvedDomain
            $resolvedForest = $connectionState.ResolvedForest
            $selectedTlsMode = $connectionState.TlsMode
        }

        $bindResult = 'Bound'
        $actualOutcome = 'PASS'
    }
    catch {
        $bindResult = if ($probeInvoked) { 'Rejected' } else { 'NotAttempted' }
        $actualOutcome = 'FAIL'
        $errorMessage = Get-RedactedProbeError -Exception $_.Exception -Credential $rowCredential
    }
    finally {
        & $maesterModule { $__MtSession.ADCredential = $null }
    }

    $errorMatched = if ($row.ExpectedOutcome -eq 'FAIL' -and -not [string]::IsNullOrWhiteSpace($row.ExpectedErrorPattern)) {
        $errorMessage -match $row.ExpectedErrorPattern
    }
    else {
        $null
    }
    $identityMatched = $null
    if ($actualOutcome -eq 'PASS') {
        $identityMatched =
            $resolvedDomain -eq $definition.Domain -and
            $resolvedForest -eq $definition.Forest
    }
    $expectationMet = $actualOutcome -eq $row.ExpectedOutcome
    if ($row.ExpectedOutcome -eq 'PASS') {
        $expectationMet = $expectationMet -and $identityMatched
    }
    if ($row.ExpectedOutcome -eq 'FAIL' -and $null -ne $errorMatched) {
        $expectationMet = $expectationMet -and $errorMatched
    }
    if ($row.FailureCondition -eq 'CertificateNameMismatch') {
        $expectationMet = $expectationMet -and $controlBindSucceeded
    }

    $artifact = [ordered]@{
        SchemaVersion        = 1
        ProbeId              = $row.Id
        RecordedAt           = [datetime]::UtcNow.ToString('o')
        Runner               = $row.Runner
        IntendedTarget       = $definition.Fqdn
        RequestedTarget      = $requestedTarget
        ConnectionTarget     = $connectionTarget
        TargetKey            = $row.Target
        TargetingMode        = $row.TargetingMode
        CredentialMode       = $row.CredentialMode
        AuthMode             = $row.AuthMode
        TlsMode              = $row.TlsMode
        FailureCondition     = $row.FailureCondition
        ControlBindSucceeded = $controlBindSucceeded
        ControlResolvedTarget = $controlResolvedTarget
        ExpectedOutcome      = $row.ExpectedOutcome
        ExpectedErrorPattern = $row.ExpectedErrorPattern
        ActualOutcome        = $actualOutcome
        FinalBindOutcome     = $bindResult
        ExpectationMet       = $expectationMet
        IdentityMatched      = $identityMatched
        ErrorMatched         = $errorMatched
        ErrorMessage         = $errorMessage
        ResolvedTarget       = $resolvedTarget
        ResolvedDomain       = $resolvedDomain
        ResolvedForest       = $resolvedForest
        SelectedTlsMode      = $selectedTlsMode
    }

    do {
        $artifactTimestamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ')
        $artifactName = 'protocol-probe-{0}-{1}-{2}.json' -f $row.Runner.ToLowerInvariant(), $row.Target.ToLowerInvariant(), $artifactTimestamp
        $artifactPath = Join-Path $EvidencePath $artifactName
        if (Test-Path -LiteralPath $artifactPath) {
            Start-Sleep -Milliseconds 20
        }
    } while (Test-Path -LiteralPath $artifactPath)
    Write-ProbeJson -InputObject $artifact -Path $artifactPath
    $results.Add([PSCustomObject]$artifact)

    $color = if ($expectationMet) { 'Green' } else { 'Red' }
    Write-Host "  Expected $($row.ExpectedOutcome), observed $actualOutcome; artifact: $artifactPath" -ForegroundColor $color
}

Write-MergedProbeSummary -Path (Join-Path $EvidencePath 'task-7-protocol-probes-success.json') `
    -NewRows @($results | Where-Object ExpectedOutcome -eq PASS)
Write-MergedProbeSummary -Path (Join-Path $EvidencePath 'task-7-protocol-probes-fail.json') `
    -NewRows @($results | Where-Object ExpectedOutcome -eq FAIL)

$failedExpectations = @($results | Where-Object { -not $_.ExpectationMet })
Write-Host "Protocol probe rows: $($results.Count); expectation mismatches: $($failedExpectations.Count)" -ForegroundColor $(if ($failedExpectations.Count -eq 0) { 'Green' } else { 'Red' })

if ($failedExpectations.Count -gt 0) {
    exit 1
}

exit 0

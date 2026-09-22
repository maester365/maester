<#
.SYNOPSIS
    Runs the certified public Active Directory E2E matrix in isolated processes.

.DESCRIPTION
    Defines the mandatory Windows and Linux public-path matrix and runs every row
    selected for the current runner in a fresh PowerShell process. Successful rows
    must complete Test-ADProtocolPrerequisites, Connect-Maester, and Invoke-Maester
    and produce JSON, Markdown, and HTML reports. Every row writes redacted
    identity/authentication/TLS evidence. Expected-failure rows must fail closed.

.PARAMETER Runner
    The lab runner executing this invocation: Win or Linux.

.PARAMETER RootCredential
    Explicit credential for misoule02.local.

.PARAMETER ChildCredential
    Explicit credential for child.misoule02.local.

.PARAMETER SeparateForestCredential
    Explicit credential for misoule03.local.

.EXAMPLE
    ./Invoke-PublicE2EMatrix.ps1 -Runner Win -RootCredential $rootCredential `
        -ChildCredential $childCredential -SeparateForestCredential $forestCredential
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'The matrix runner displays progress; JSON files provide machine-readable results.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Credential parameters are selected dynamically for isolated matrix rows.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'A random one-use value intentionally creates the invalid-credential negative test and is never persisted as plaintext.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    '',
    Justification = 'CredentialMode is a matrix label; all actual credentials are PSCredential objects.'
)]
[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName = 'Orchestrator')]
    [ValidateSet('Win', 'Linux')]
    [string]$Runner,

    [Parameter(Mandatory, ParameterSetName = 'Orchestrator')]
    [System.Management.Automation.PSCredential]$RootCredential,

    [Parameter(Mandatory, ParameterSetName = 'Orchestrator')]
    [System.Management.Automation.PSCredential]$ChildCredential,

    [Parameter(Mandatory, ParameterSetName = 'Orchestrator')]
    [System.Management.Automation.PSCredential]$SeparateForestCredential,

    [Parameter(ParameterSetName = 'Orchestrator')]
    [string]$MaesterModulePath = (Join-Path $PSScriptRoot '..\..\..\powershell'),

    [Parameter(ParameterSetName = 'Orchestrator')]
    [string]$TestPath = (Join-Path $PSScriptRoot '..\..\..\tests'),

    [Parameter(ParameterSetName = 'Orchestrator')]
    [string]$OutputPath = (Join-Path $PSScriptRoot 'evidence\reports'),

    [Parameter(ParameterSetName = 'Orchestrator')]
    [string]$EvidencePath = (Join-Path $PSScriptRoot 'evidence'),

    [Parameter(ParameterSetName = 'Orchestrator')]
    [ValidateRange(1, 1440)]
    [int]$RowTimeoutMinutes = 120,

    [Parameter(Mandatory, ParameterSetName = 'Worker')]
    [switch]$Worker,

    [Parameter(Mandatory, ParameterSetName = 'Worker')]
    [string]$PipeName,

    [Parameter(Mandatory, ParameterSetName = 'Worker')]
    [string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-RedactedMatrixError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    $message = [string]$Exception.Message
    if ($null -ne $Credential) {
        $plainTextPassword = $Credential.GetNetworkCredential().Password
        if (-not [string]::IsNullOrEmpty($plainTextPassword)) {
            $message = $message -replace [regex]::Escape($plainTextPassword), '<redacted>'
        }
        $plainTextPassword = $null
    }
    $message = $message -replace '(?i)(ldap(?:s)?://)?[^/\s:@]+:[^@\s/]+@', '$1<redacted>@'
    $message = $message -replace '(?i)(password|pwd|passphrase)\s*[=:]\s*[^\s;,]+', '$1=<redacted>'

    if ([string]::IsNullOrWhiteSpace($message)) {
        return 'The public Active Directory path failed without an error message.'
    }
    return $message
}

function Write-MatrixJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $InputObject | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8
}

if ($Worker.IsPresent) {
    $pipeClient = [System.IO.Pipes.NamedPipeClientStream]::new(
        '.',
        $PipeName,
        [System.IO.Pipes.PipeDirection]::In,
        [System.IO.Pipes.PipeOptions]::CurrentUserOnly
    )
    try {
        $pipeClient.Connect(30000)
        $pipeReader = [System.IO.StreamReader]::new($pipeClient)
        try {
            $workerInput = [System.Management.Automation.PSSerializer]::Deserialize($pipeReader.ReadToEnd())
        }
        finally {
            $pipeReader.Dispose()
        }
    }
    finally {
        $pipeClient.Dispose()
    }

    $row = $workerInput.Row
    $rowCredential = $workerInput.Credential
    $startedAt = [datetime]::UtcNow
    $actualOutcome = 'FAIL'
    $errorMessage = $null
    $prerequisiteReady = $false
    $connectionDetails = $null
    $reportFiles = @()
    $testResultCount = 0
    $expectationMet = $false
    $currentStage = 'Prerequisite'
    $failedStage = $null

    try {
        $prerequisiteParameters = @{
            TargetName        = $row.Fqdn
            MaesterModulePath = $workerInput.MaesterModulePath
            SkipCertificateCheck = $true
        }
        if ($null -ne $rowCredential) {
            $prerequisiteParameters.Credential = $rowCredential
        }
        $prerequisiteResult = & $workerInput.PrerequisiteScript @prerequisiteParameters
        $prerequisiteReady = [bool]$prerequisiteResult.IsReady
        if (-not $prerequisiteReady) {
            throw "Protocol prerequisites failed for '$($row.Fqdn)'."
        }

        $currentStage = 'ModuleImport'
        $manifestPath = Join-Path $workerInput.MaesterModulePath 'Maester.psd1'
        Import-Module $manifestPath -Force

        $currentStage = 'Connect'
        $connectParameters = @{
            Service                     = 'ActiveDirectory'
            ActiveDirectoryAuthMode     = $row.AuthMode
            ActiveDirectoryTlsMode      = $row.TlsMode
        }
        if ($row.TargetingMode -eq 'Explicit') {
            $connectParameters.ActiveDirectoryServer = $row.Fqdn
        }
        if ($row.FailureCondition -eq 'SelectorMismatch') {
            $connectParameters.ActiveDirectoryDomain = 'child.misoule02.local'
        }
        if ($null -ne $rowCredential) {
            $connectParameters.ActiveDirectoryCredential = $rowCredential
        }

        Connect-Maester @connectParameters | Out-Null
        $connectionDetails = (Test-MtConnection -Service ActiveDirectory -Details).ActiveDirectory
        if ($null -eq $connectionDetails -or -not $connectionDetails.ProtocolValidated) {
            throw 'The certified Active Directory protocol path did not return a validated connection.'
        }

        if ($connectionDetails.ResolvedDomain -ne $row.Domain -or $connectionDetails.ResolvedForest -ne $row.Forest) {
            throw "Resolved identity does not match requested target '$($row.Target)': expected domain '$($row.Domain)' and forest '$($row.Forest)', received domain '$($connectionDetails.ResolvedDomain)' and forest '$($connectionDetails.ResolvedForest)'."
        }
        if ($connectionDetails.AuthenticationMode -ne $row.AuthMode -or $connectionDetails.TlsMode -ne $row.TlsMode) {
            throw 'The selected authentication or TLS mode does not match the matrix row.'
        }

        $currentStage = 'Invoke'
        $adTestPaths = @(
            (Join-Path $workerInput.TestPath 'Maester\ad'),
            (Join-Path $workerInput.TestPath 'ad')
        )
        $adTestPath = $adTestPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($adTestPath)) {
            throw "No AD test path was found beneath '$($workerInput.TestPath)'."
        }

        $reportPrefix = 'AD-TestResults-{0}-{1}' -f $row.Id, $workerInput.ArtifactTimestamp
        $maesterResults = @(Invoke-Maester -Path $adTestPath -Tag AD -NonInteractive -SkipGraphConnect -PassThru `
            -OutputFolder $workerInput.OutputPath -OutputFolderFileName $reportPrefix)
        if ($maesterResults.Count -eq 0) {
            throw 'Invoke-Maester returned no test result object.'
        }
        $totalCountProperty = $maesterResults[0].PSObject.Properties['TotalCount']
        $testResultCount = if ($null -eq $totalCountProperty) { $maesterResults.Count } else { [int]$totalCountProperty.Value }
        if ($testResultCount -le 0) {
            throw 'Invoke-Maester reported that zero AD tests ran.'
        }

        $currentStage = 'ReportValidation'
        $reportFiles = @(
            (Join-Path $workerInput.OutputPath "$reportPrefix.json"),
            (Join-Path $workerInput.OutputPath "$reportPrefix.md"),
            (Join-Path $workerInput.OutputPath "$reportPrefix.html")
        )
        $missingReports = @($reportFiles | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
        if ($missingReports.Count -gt 0) {
            throw "Invoke-Maester did not produce all mandatory report formats: $($missingReports -join ', ')."
        }

        $actualOutcome = 'PASS'
    }
    catch {
        $failedStage = $currentStage
        $errorMessage = ConvertTo-RedactedMatrixError -Exception $_.Exception -Credential $rowCredential
    }
    finally {
        $expectationMet = $actualOutcome -eq $row.ExpectedOutcome
        if ($row.ExpectedOutcome -eq 'FAIL' -and -not [string]::IsNullOrWhiteSpace($row.ExpectedErrorPattern)) {
            $expectationMet = $expectationMet -and $errorMessage -match $row.ExpectedErrorPattern
        }

        $evidence = [ordered]@{
            SchemaVersion        = 1
            RowId                = $row.Id
            RecordedAt           = [datetime]::UtcNow.ToString('o')
            ProcessId            = $PID
            SessionId            = $workerInput.SessionId
            Runner               = $row.Runner
            RunnerVm             = $row.RunnerVm
            Target               = $row.Target
            ExpectedOutcome      = $row.ExpectedOutcome
            ActualOutcome        = $actualOutcome
            ExpectationMet       = $expectationMet
            FailureCondition     = $row.FailureCondition
            ExpectedErrorPattern = $row.ExpectedErrorPattern
            ErrorMessage         = $errorMessage
            FailedStage          = $failedStage
            PrerequisiteReady    = $prerequisiteReady
            ProtocolValidated    = [bool]($null -ne $connectionDetails -and $connectionDetails.ProtocolValidated)
            Targeting            = [ordered]@{
                Mode             = $row.TargetingMode
                RequestedServer  = if ($row.TargetingMode -eq 'Explicit') { $row.Fqdn } else { $null }
                RequestedDomain  = if ($row.FailureCondition -eq 'SelectorMismatch') { 'child.misoule02.local' } else { $null }
                ExpectedDomain   = $row.Domain
                ExpectedForest   = $row.Forest
                ResolvedServer   = if ($null -eq $connectionDetails) { $null } else { $connectionDetails.ResolvedServer }
                ResolvedDomain   = if ($null -eq $connectionDetails) { $null } else { $connectionDetails.ResolvedDomain }
                ResolvedForest   = if ($null -eq $connectionDetails) { $null } else { $connectionDetails.ResolvedForest }
            }
            Authentication      = [ordered]@{
                CredentialMode  = $row.CredentialMode
                CredentialUser  = if ($null -eq $rowCredential) { $null } else { $rowCredential.UserName }
                RequestedMode   = $row.AuthMode
                SelectedMode    = if ($null -eq $connectionDetails) { $null } else { $connectionDetails.AuthenticationMode }
            }
            Transport           = [ordered]@{
                RequestedTlsMode = $row.TlsMode
                SelectedTlsMode  = if ($null -eq $connectionDetails) { $null } else { $connectionDetails.TlsMode }
            }
            Reports             = $reportFiles
            TestResultCount     = $testResultCount
            StartedAt           = $startedAt.ToString('o')
            CompletedAt         = [datetime]::UtcNow.ToString('o')
        }

        Write-MatrixJson -InputObject $evidence -Path $workerInput.EvidenceFile
        [PSCustomObject]$evidence | Export-Clixml -LiteralPath $ResultPath
        if (-not $IsWindows) {
            [System.IO.File]::SetUnixFileMode(
                $ResultPath,
                [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite
            )
        }
    }

    if ($expectationMet) {
        exit 0
    }
    exit 1
}

function Get-PublicMatrixRow {
    param(
        [string]$Id,
        [string]$Runner,
        [string]$RunnerVm,
        [string]$Target,
        [string]$Fqdn,
        [string]$Domain,
        [string]$Forest,
        [string]$TargetingMode,
        [string]$CredentialKind,
        [string]$AuthMode,
        [string]$TlsMode,
        [string]$ExpectedOutcome,
        [string]$ExpectedErrorPattern = $null,
        [string]$FailureCondition = $null
    )

    [PSCustomObject]@{
        Id                   = $Id
        Runner               = $Runner
        RunnerVm             = $RunnerVm
        Target               = $Target
        Fqdn                 = $Fqdn
        Domain               = $Domain
        Forest               = $Forest
        TargetingMode        = $TargetingMode
        CredentialMode       = $CredentialKind
        AuthMode             = $AuthMode
        TlsMode              = $TlsMode
        ExpectedOutcome      = $ExpectedOutcome
        ExpectedErrorPattern = $ExpectedErrorPattern
        FailureCondition     = $FailureCondition
        Mandatory            = $true
    }
}

$dc02 = @{ Target = 'DC02'; Fqdn = 'MiSouleDC02.misoule02.local'; Domain = 'misoule02.local'; Forest = 'misoule02.local' }
$dc03 = @{ Target = 'DC03'; Fqdn = 'MiSouleDC03.child.misoule02.local'; Domain = 'child.misoule02.local'; Forest = 'misoule02.local' }
$dc04 = @{ Target = 'DC04'; Fqdn = 'MiSouleDC04.misoule03.local'; Domain = 'misoule03.local'; Forest = 'misoule03.local' }

# Matrix design notes:
# - Windows runner (MiSouleRunnerWin) exercises all four implicit/explicit targeting + credential
#   combinations for the root forest (DC02), plus child-domain and separate-forest rows.
# - Linux runner (MiSouleRunnerLinux) is enrolled in misoule02.local via realmd/SSSD and CAN
#   obtain Kerberos tickets, but Connect-MtAdTarget rejects implicit targeting on non-Windows
#   platforms (line 372). Therefore Linux PASS rows use explicit targeting only.
# - Linux implicit targeting is covered by mandatory negative row N2.
# No trust-aware separate-forest success row is approved: the lab intentionally
# has no forest trust. All separate-forest success rows therefore use explicit credentials.
$matrix = @(
    Get-PublicMatrixRow -Id '1-win-dc02-implicit-implicit-negotiate-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc02 -TargetingMode Implicit -CredentialKind Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '2-win-dc02-implicit-explicit-negotiate-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc02 -TargetingMode Implicit -CredentialKind Explicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '3-win-dc02-explicit-implicit-negotiate-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc02 -TargetingMode Explicit -CredentialKind Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '4-win-dc02-explicit-explicit-basic-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc02 -TargetingMode Explicit -CredentialKind Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '5-win-dc03-explicit-implicit-negotiate-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc03 -TargetingMode Explicit -CredentialKind Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '6-win-dc03-explicit-explicit-basic-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc03 -TargetingMode Explicit -CredentialKind Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '7-win-dc04-explicit-explicit-basic-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc04 -TargetingMode Explicit -CredentialKind Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '8-linux-dc02-explicit-explicit-basic-ldaps' -Runner Linux -RunnerVm MiSouleRunnerLinux @dc02 -TargetingMode Explicit -CredentialKind Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '9-linux-dc03-explicit-explicit-basic-ldaps' -Runner Linux -RunnerVm MiSouleRunnerLinux @dc03 -TargetingMode Explicit -CredentialKind Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id '10-linux-dc04-explicit-explicit-basic-ldaps' -Runner Linux -RunnerVm MiSouleRunnerLinux @dc04 -TargetingMode Explicit -CredentialKind Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome PASS
    Get-PublicMatrixRow -Id 'N1-win-dc02-implicit-implicit-negotiate-none' -Runner Win -RunnerVm MiSouleRunnerWin @dc02 -TargetingMode Implicit -CredentialKind Implicit -AuthMode Negotiate -TlsMode None -ExpectedOutcome FAIL -ExpectedErrorPattern '(?i)(ActiveDirectoryTlsMode|validation set|does not belong to the set)' -FailureCondition NoTls
    Get-PublicMatrixRow -Id 'N2-linux-dc02-implicit-implicit-negotiate-ldaps' -Runner Linux -RunnerVm MiSouleRunnerLinux @dc02 -TargetingMode Implicit -CredentialKind Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome FAIL -ExpectedErrorPattern 'Non-Windows platforms require an explicit Active Directory endpoint' -FailureCondition UnsupportedImplicitTargeting
    Get-PublicMatrixRow -Id 'N3-win-dc04-implicit-implicit-negotiate-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc04 -TargetingMode Implicit -CredentialKind Implicit -AuthMode Negotiate -TlsMode Ldaps -ExpectedOutcome FAIL -ExpectedErrorPattern 'Resolved identity does not match requested target' -FailureCondition SeparateForestImplicitTargeting
    Get-PublicMatrixRow -Id 'N4-win-dc02-explicit-invalid-basic-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc02 -TargetingMode Explicit -CredentialKind Invalid -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome FAIL -ExpectedErrorPattern '(?i)(authentication|credential|logon|invalid credentials|bind.*(fail|reject))' -FailureCondition InvalidCredential
    Get-PublicMatrixRow -Id 'N5-win-dc02-selector-mismatch-explicit-basic-ldaps' -Runner Win -RunnerVm MiSouleRunnerWin @dc02 -TargetingMode Explicit -CredentialKind Explicit -AuthMode Basic -TlsMode Ldaps -ExpectedOutcome FAIL -ExpectedErrorPattern 'Explicit selector values must resolve to the same forest/domain/server' -FailureCondition SelectorMismatch
)

$actualRunner = if ($IsWindows) { 'Win' } else { 'Linux' }
if ($Runner -ne $actualRunner) {
    throw "Runner '$Runner' does not match the current PowerShell platform '$actualRunner'."
}

foreach ($path in @($OutputPath, $EvidencePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}
$MaesterModulePath = (Resolve-Path -LiteralPath $MaesterModulePath).Path
$TestPath = (Resolve-Path -LiteralPath $TestPath).Path
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path
$EvidencePath = (Resolve-Path -LiteralPath $EvidencePath).Path
$prerequisiteScript = Join-Path $PSScriptRoot 'Test-ADProtocolPrerequisites.ps1'
$pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
$selectedRows = @($matrix | Where-Object Runner -eq $Runner)
$results = [System.Collections.Generic.List[object]]::new()

foreach ($row in $selectedRows) {
    $artifactTimestamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ')
    $safeTarget = $row.Target.ToLowerInvariant()
    $evidenceFile = Join-Path $EvidencePath ('AD-PublicPath-{0}-{1}-{2}.json' -f $row.Runner.ToLowerInvariant(), $safeTarget, $artifactTimestamp)
    $sessionId = [guid]::NewGuid().ToString()
    $rowCredential = switch ($row.CredentialMode) {
        'Explicit' {
            switch ($row.Target) {
                'DC02' { $RootCredential }
                'DC03' { $ChildCredential }
                'DC04' { $SeparateForestCredential }
            }
        }
        'Invalid' {
            $invalidPassword = ConvertTo-SecureString ([guid]::NewGuid().ToString()) -AsPlainText -Force
            $invalidUser = 'maester-invalid-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8)
            [PSCredential]::new($invalidUser, $invalidPassword)
        }
        default { $null }
    }

    $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "maester-public-matrix-$sessionId"
    New-Item -Path $tempDirectory -ItemType Directory -Force | Out-Null
    if (-not $IsWindows) {
        [System.IO.File]::SetUnixFileMode(
            $tempDirectory,
            [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite -bor [System.IO.UnixFileMode]::UserExecute
        )
    }
    $resultFile = Join-Path $tempDirectory 'result.clixml'
    $pipeName = "maester-public-matrix-$sessionId"
    $process = $null
    $pipeServer = [System.IO.Pipes.NamedPipeServerStream]::new(
        $pipeName,
        [System.IO.Pipes.PipeDirection]::Out,
        1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte,
        [System.IO.Pipes.PipeOptions]::Asynchronous -bor [System.IO.Pipes.PipeOptions]::CurrentUserOnly
    )
    try {
        $serializedInput = [System.Management.Automation.PSSerializer]::Serialize([PSCustomObject]@{
            Row                = $row
            Credential         = $rowCredential
            MaesterModulePath  = $MaesterModulePath
            TestPath           = $TestPath
            OutputPath         = $OutputPath
            PrerequisiteScript = $prerequisiteScript
            EvidenceFile       = $evidenceFile
            ArtifactTimestamp  = $artifactTimestamp
            SessionId          = $sessionId
        }, 10)

        Write-Host "Running $($row.Id) in a fresh pwsh process..." -ForegroundColor Cyan
        $process = Start-Process -FilePath $pwshPath -ArgumentList @(
            '-NoLogo',
            '-NoProfile',
            '-NonInteractive',
            '-File',
            "`"$PSCommandPath`"",
            '-Worker',
            '-PipeName',
            $pipeName,
            '-ResultPath',
            "`"$resultFile`""
        ) -PassThru

        $pipeConnectionTask = $pipeServer.WaitForConnectionAsync()
        if (-not $pipeConnectionTask.Wait(60000)) {
            throw "Worker for row '$($row.Id)' did not connect to its credential pipe within 60 seconds."
        }
        $pipeWriter = [System.IO.StreamWriter]::new($pipeServer)
        try {
            $pipeWriter.Write($serializedInput)
        }
        finally {
            $pipeWriter.Dispose()
            $serializedInput = $null
        }
        $rowTimeoutMilliseconds = $RowTimeoutMinutes * 60 * 1000
        if (-not $process.WaitForExit($rowTimeoutMilliseconds)) {
            throw "Worker for row '$($row.Id)' exceeded the $RowTimeoutMinutes minute time limit."
        }

        if (-not (Test-Path -LiteralPath $resultFile -PathType Leaf)) {
            throw "Worker process $($process.Id) exited with code $($process.ExitCode) without producing a result."
        }
        $result = Import-Clixml -LiteralPath $resultFile
        $result | Add-Member -NotePropertyName WorkerExitCode -NotePropertyValue $process.ExitCode
        $results.Add($result)
        $color = if ($result.ExpectationMet -and $process.ExitCode -eq 0) { 'Green' } else { 'Red' }
        Write-Host "  Expected $($row.ExpectedOutcome), observed $($result.ActualOutcome); evidence: $evidenceFile" -ForegroundColor $color
    }
    catch {
        $results.Add([PSCustomObject]@{
            RowId            = $row.Id
            Runner           = $row.Runner
            Target           = $row.Target
            ExpectedOutcome  = $row.ExpectedOutcome
            ActualOutcome    = 'HARNESS_ERROR'
            ExpectationMet   = $false
            ErrorMessage     = ConvertTo-RedactedMatrixError -Exception $_.Exception -Credential $rowCredential
            ProcessId        = $null
            SessionId        = $sessionId
            Reports          = @()
            PrerequisiteReady = $false
            ProtocolValidated = $false
            WorkerExitCode    = if ($null -eq $process) { $null } else { $process.ExitCode }
        })
    }
    finally {
        if ($null -ne $process -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        if ($null -ne $pipeServer) {
            $pipeServer.Dispose()
        }
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $tempDirectory) {
            Write-Warning "Temporary matrix directory '$tempDirectory' could not be removed. Delete it manually."
        }
        $rowCredential = $null
    }
}

$summaryPath = Join-Path $EvidencePath 'task-8-public-matrix-summary.json'
$failureSummaryPath = Join-Path $EvidencePath 'task-8-public-matrix-failures.json'
$priorRows = @()
if (Test-Path -LiteralPath $summaryPath -PathType Leaf) {
    try {
        $priorSummary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
        if ($null -ne $priorSummary.PSObject.Properties['ExecutedRows']) {
            $priorRows = @($priorSummary.ExecutedRows | Where-Object { $_.Runner -ne $Runner })
        }
    }
    catch {
        Write-Warning "Existing matrix summary '$summaryPath' could not be merged and will be replaced."
    }
}
$combinedResults = @($priorRows) + @($results)
$combinedResults = @($combinedResults | Group-Object RowId | ForEach-Object { $_.Group | Select-Object -Last 1 })
$successfulPublicRows = @($combinedResults | Where-Object {
        $_.ExpectedOutcome -eq 'PASS' -and
        $_.ExpectationMet -eq $true -and
        $_.ProtocolValidated -eq $true
    })
$livePublicPath = $successfulPublicRows.Count -eq @($matrix | Where-Object ExpectedOutcome -eq PASS).Count
$completedRowCount = @($combinedResults | Select-Object -ExpandProperty RowId -Unique).Count
$summary = [ordered]@{
    SchemaVersion              = 1
    RecordedAt                 = [datetime]::UtcNow.ToString('o')
    LivePublicPath             = $livePublicPath
    Status                     = if ($completedRowCount -eq $matrix.Count) { 'Complete' } else { 'Partial' }
    LastRunner                 = $Runner
    RunnerVms                  = @('MiSouleRunnerWin', 'MiSouleRunnerLinux')
    ApprovedTrustAwareRows     = @()
    TrustAwareRowStatus        = 'No separate-forest trust is configured; no trust-aware success row is approved.'
    MatrixDefinition           = $matrix
    ExecutedRows               = $combinedResults
    ExpectedPassCount          = @($matrix | Where-Object ExpectedOutcome -eq PASS).Count
    ExpectedFailureCount       = @($matrix | Where-Object ExpectedOutcome -eq FAIL).Count
    ExecutedPassCount          = @($combinedResults | Where-Object ExpectedOutcome -eq PASS).Count
    ExecutedFailureCount       = @($combinedResults | Where-Object ExpectedOutcome -eq FAIL).Count
    ExpectationMismatchCount   = @($combinedResults | Where-Object { -not $_.ExpectationMet }).Count
}
$failureSummary = [ordered]@{
    SchemaVersion  = 1
    RecordedAt     = $summary.RecordedAt
    LivePublicPath = $livePublicPath
    Status         = $summary.Status
    FailureDefinition = @($matrix | Where-Object ExpectedOutcome -eq FAIL)
    Rows           = @($combinedResults | Where-Object ExpectedOutcome -eq FAIL)
}
Write-MatrixJson -InputObject $summary -Path $summaryPath
Write-MatrixJson -InputObject $failureSummary -Path $failureSummaryPath

$expectationMismatches = @($results | Where-Object { -not $_.ExpectationMet -or $_.WorkerExitCode -ne 0 })
Write-Host "Public E2E rows: $($results.Count); expectation mismatches: $($expectationMismatches.Count)" -ForegroundColor $(if ($expectationMismatches.Count -eq 0) { 'Green' } else { 'Red' })
if ($expectationMismatches.Count -gt 0) {
    exit 1
}
exit 0

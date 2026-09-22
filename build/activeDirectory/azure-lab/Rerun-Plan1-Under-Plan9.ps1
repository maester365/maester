<#
.SYNOPSIS
    Reruns Plan 1 through the Plan 9 hard-gated validation process.

.DESCRIPTION
    Runs the lab preflight locally, then executes the protocol and public E2E
    matrices on both lab runners through existing PowerShell remoting sessions.
    Later stages never run when an earlier gate fails. All runner artifacts are
    copied into a timestamped local evidence directory before a unified report
    compares the result with the five scenarios blocked in the old Plan 1 report.

.PARAMETER TagName
    Azure resource tag key used by the lab preflight.

.PARAMETER TagValue
    Azure lab identifier and resource tag value.

.PARAMETER WindowsRunnerSession
    Open PSSession to MiSouleRunnerWin. The session transport must already be
    authenticated; no runner-management credential is persisted by this script.

.PARAMETER LinuxRunnerSession
    Open PSSession to MiSouleRunnerLinux.

.PARAMETER RootCredential
    Explicit low-privilege credential for misoule02.local.

.PARAMETER ChildCredential
    Explicit low-privilege credential for child.misoule02.local.

.PARAMETER SeparateForestCredential
    Explicit low-privilege credential for misoule03.local.

.PARAMETER WindowsRepositoryPath
    Repository root on the Windows runner.

.PARAMETER LinuxRepositoryPath
    Repository root on the Linux runner.

.PARAMETER RunnerTimeoutMinutes
    Maximum time allowed for each runner matrix process.

.EXAMPLE
    ./Rerun-Plan1-Under-Plan9.ps1 -TagName maester-lab-id -TagValue $labId `
        -WindowsRunnerSession $windowsSession -LinuxRunnerSession $linuxSession `
        -RootCredential $rootCredential -ChildCredential $childCredential `
        -SeparateForestCredential $separateForestCredential
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'The orchestration reports gate progress; JSON is the authoritative output.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Credential parameters are consumed by Invoke-RunnerMatrix through its remote scriptblock closure.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseUsingScopeModifierInNewRunspaces',
    '',
    Justification = 'The remote scriptblock variables are explicitly declared parameters populated by ArgumentList.'
)]
param(
    [Parameter()]
    [string]$ResourceGroupName = 'RG_5100_MiSoule_2',

    [Parameter(Mandatory)]
    [string]$TagName,

    [Parameter(Mandatory)]
    [string]$TagValue,

    [Parameter(Mandatory)]
    [System.Management.Automation.Runspaces.PSSession]$WindowsRunnerSession,

    [Parameter(Mandatory)]
    [System.Management.Automation.Runspaces.PSSession]$LinuxRunnerSession,

    [Parameter(Mandatory)]
    [System.Management.Automation.PSCredential]$RootCredential,

    [Parameter(Mandatory)]
    [System.Management.Automation.PSCredential]$ChildCredential,

    [Parameter(Mandatory)]
    [System.Management.Automation.PSCredential]$SeparateForestCredential,

    [Parameter()]
    [string]$WindowsRepositoryPath = 'C:\Maester',

    [Parameter()]
    [string]$LinuxRepositoryPath = '/opt/maester',

    [Parameter()]
    [ValidateRange(1, 720)]
    [int]$RunnerTimeoutMinutes = 180,

    [Parameter()]
    [string]$EvidencePath = (Join-Path $PSScriptRoot 'evidence')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$plan9Reference = '.sisyphus/plans/09-ad-e2e-validation-closure.md#task-10'
$oldPlan1Reference = '.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md (2026-09-11)'
$rerunStartedAt = [datetime]::UtcNow
$artifactTimestamp = $rerunStartedAt.ToString('yyyyMMddTHHmmssZ')
$rerunDirectory = Join-Path $EvidencePath "plan1-rerun-$artifactTimestamp"
$reportPath = Join-Path $EvidencePath "plan1-rerun-$artifactTimestamp.json"

$expectedProtocolRows = @(
    'win-dc02-implicit-implicit-negotiate-ldaps',
    'win-dc02-implicit-explicit-negotiate-ldaps',
    'win-dc02-explicit-implicit-negotiate-ldaps',
    'win-dc02-explicit-explicit-basic-ldaps',
    'win-dc03-explicit-implicit-negotiate-ldaps',
    'win-dc03-explicit-explicit-basic-ldaps',
    'win-dc04-explicit-explicit-basic-ldaps',
    'linux-dc02-explicit-explicit-basic-ldaps',
    'linux-dc03-explicit-explicit-basic-ldaps',
    'linux-dc04-explicit-explicit-basic-ldaps',
    'win-dc02-explicit-explicit-basic-none',
    'win-dc02-implicit-implicit-negotiate-starttls',
    'linux-dc02-explicit-explicit-basic-starttls',
    'win-dc04-explicit-implicit-negotiate-ldaps-no-trust',
    'win-dc02-explicit-explicit-negotiate-starttls-broken-cert',
    'linux-dc02-explicit-explicit-negotiate-starttls-broken-cert'
)
$expectedPublicRows = @(
    '1-win-dc02-implicit-implicit-negotiate-ldaps',
    '2-win-dc02-implicit-explicit-negotiate-ldaps',
    '3-win-dc02-explicit-implicit-negotiate-ldaps',
    '4-win-dc02-explicit-explicit-basic-ldaps',
    '5-win-dc03-explicit-implicit-negotiate-ldaps',
    '6-win-dc03-explicit-explicit-basic-ldaps',
    '7-win-dc04-explicit-explicit-basic-ldaps',
    '8-linux-dc02-explicit-explicit-basic-ldaps',
    '9-linux-dc03-explicit-explicit-basic-ldaps',
    '10-linux-dc04-explicit-explicit-basic-ldaps',
    'N1-win-dc02-implicit-implicit-negotiate-none',
    'N2-linux-dc02-implicit-implicit-negotiate-ldaps',
    'N3-win-dc04-implicit-implicit-negotiate-ldaps',
    'N4-win-dc02-explicit-invalid-basic-ldaps',
    'N5-win-dc02-selector-mismatch-explicit-basic-ldaps'
)

function Write-RerunJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $json = $InputObject | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Assert-RunnerSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$Session,

        [Parameter(Mandatory)]
        [string[]]$ExpectedComputerName
    )

    if ($Session.State -ne 'Opened') {
        throw "The PSSession for '$($ExpectedComputerName -join '/')' is not open."
    }

    $remoteComputerName = [string](Invoke-Command -Session $Session -ScriptBlock {
        [System.Net.Dns]::GetHostName()
    })
    if ($remoteComputerName -notin $ExpectedComputerName) {
        throw "The runner session resolved to '$remoteComputerName', expected '$($ExpectedComputerName -join "' or '")'."
    }
}

function Invoke-RunnerMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$Session,

        [Parameter(Mandatory)]
        [ValidateSet('Windows', 'Linux')]
        [string]$Runner,

        [Parameter(Mandatory)]
        [ValidateSet('Protocol', 'Public')]
        [string]$Matrix,

        [Parameter(Mandatory)]
        [string]$RepositoryPath,

        [Parameter(Mandatory)]
        [string]$LocalDestination
    )

    $remoteResult = Invoke-Command -Session $Session -ArgumentList @(
        $Runner,
        $Matrix,
        $RepositoryPath,
        $artifactTimestamp,
        $RootCredential,
        $ChildCredential,
        $SeparateForestCredential,
        $RunnerTimeoutMinutes
    ) -ScriptBlock {
        param(
            $RunnerName,
            $MatrixName,
            $RepoPath,
            $Timestamp,
            $Root,
            $Child,
            $SeparateForest,
            $TimeoutMinutes
        )

        $ErrorActionPreference = 'Stop'
        $labPath = Join-Path $RepoPath 'build/activeDirectory/azure-lab'
        $remoteEvidencePath = Join-Path $labPath "evidence/plan1-rerun-$Timestamp/$($MatrixName.ToLowerInvariant())"
        $remoteReportPath = Join-Path $remoteEvidencePath 'reports'
        New-Item -Path $remoteEvidencePath -ItemType Directory -Force | Out-Null

        $sessionId = [guid]::NewGuid().ToString()
        $pipeName = "maester-plan1-rerun-$sessionId"
        $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "maester-plan1-rerun-$sessionId"
        $launcherFile = Join-Path $tempDirectory 'Invoke-Matrix.ps1'
        $pipeServer = $null
        $process = $null
        try {
            New-Item -Path $tempDirectory -ItemType Directory -Force | Out-Null
            if (-not $IsWindows) {
                [System.IO.File]::SetUnixFileMode(
                    $tempDirectory,
                    [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite -bor [System.IO.UnixFileMode]::UserExecute
                )
            }
            $matrixScript = if ($MatrixName -eq 'Protocol') {
                Join-Path $labPath 'Invoke-ProtocolProbeMatrix.ps1'
            }
            else {
                Join-Path $labPath 'Invoke-PublicE2EMatrix.ps1'
            }
            $runnerArgument = if ($MatrixName -eq 'Public' -and $RunnerName -eq 'Windows') { 'Win' } else { $RunnerName }
            $launcher = @'
param(
    [Parameter(Mandatory)][string]$PipeName,
    [Parameter(Mandatory)][string]$RunnerArgument,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [Parameter(Mandatory)][string]$MatrixName,
    [Parameter(Mandatory)][string]$ReportDirectory,
    [Parameter(Mandatory)][string]$MatrixScript
)
$ErrorActionPreference = 'Stop'
$pipeClient = [System.IO.Pipes.NamedPipeClientStream]::new(
    '.',
    $PipeName,
    [System.IO.Pipes.PipeDirection]::In,
    [System.IO.Pipes.PipeOptions]::CurrentUserOnly
)
try {
    $pipeClient.Connect(30000)
    $reader = [System.IO.StreamReader]::new($pipeClient)
    try {
        $credentials = [System.Management.Automation.PSSerializer]::Deserialize($reader.ReadToEnd())
    }
    finally {
        $reader.Dispose()
    }
}
finally {
    $pipeClient.Dispose()
}
$parameters = @{
    Runner                   = $RunnerArgument
    RootCredential           = $credentials.Root
    ChildCredential          = $credentials.Child
    SeparateForestCredential = $credentials.SeparateForest
    EvidencePath             = $EvidenceDirectory
}
if ($MatrixName -eq 'Public') {
    $parameters.OutputPath = $ReportDirectory
}
& $MatrixScript @parameters
exit $LASTEXITCODE
'@
            [System.IO.File]::WriteAllText($launcherFile, $launcher, [System.Text.UTF8Encoding]::new($false))
            if (-not $IsWindows) {
                [System.IO.File]::SetUnixFileMode(
                    $launcherFile,
                    [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite
                )
            }

            $pipeServer = [System.IO.Pipes.NamedPipeServerStream]::new(
                $pipeName,
                [System.IO.Pipes.PipeDirection]::Out,
                1,
                [System.IO.Pipes.PipeTransmissionMode]::Byte,
                [System.IO.Pipes.PipeOptions]::Asynchronous -bor [System.IO.Pipes.PipeOptions]::CurrentUserOnly
            )
            $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $processStartInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
            $processStartInfo.UseShellExecute = $false
            foreach ($argument in @(
                '-NoLogo', '-NoProfile', '-NonInteractive', '-File', $launcherFile,
                '-PipeName', $pipeName,
                '-RunnerArgument', $runnerArgument,
                '-EvidenceDirectory', $remoteEvidencePath,
                '-MatrixName', $MatrixName,
                '-ReportDirectory', $remoteReportPath,
                '-MatrixScript', $matrixScript
            )) {
                $processStartInfo.ArgumentList.Add($argument)
            }
            $process = [System.Diagnostics.Process]::Start($processStartInfo)
            if (-not $pipeServer.WaitForConnectionAsync().Wait([timespan]::FromSeconds(60))) {
                throw 'The matrix child process did not connect to its credential pipe within 60 seconds.'
            }
            $writer = [System.IO.StreamWriter]::new($pipeServer)
            try {
                $serializedCredentials = [System.Management.Automation.PSSerializer]::Serialize([PSCustomObject]@{
                    Root           = $Root
                    Child          = $Child
                    SeparateForest = $SeparateForest
                }, 4)
                $writer.Write($serializedCredentials)
            }
            finally {
                $serializedCredentials = $null
                $writer.Dispose()
            }
            $timeoutMilliseconds = [int][timespan]::FromMinutes($TimeoutMinutes).TotalMilliseconds
            if (-not $process.WaitForExit($timeoutMilliseconds)) {
                try {
                    $process.Kill($true)
                }
                catch {
                    Write-Verbose "Unable to terminate timed-out child process $($process.Id): $($_.Exception.Message)"
                }
                throw "The $RunnerName $MatrixName matrix exceeded its $TimeoutMinutes minute timeout."
            }
            [PSCustomObject]@{
                Runner             = $RunnerName
                Matrix             = $MatrixName
                ExitCode           = $process.ExitCode
                RemoteEvidencePath = $remoteEvidencePath
            }
        }
        finally {
            if ($null -ne $pipeServer) {
                $pipeServer.Dispose()
            }
            if ($null -ne $process) {
                $process.Dispose()
            }
            Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $tempDirectory) {
                throw "Sensitive runner temporary directory '$tempDirectory' could not be removed."
            }
        }
    }

    if (-not (Test-Path -LiteralPath $LocalDestination)) {
        New-Item -Path $LocalDestination -ItemType Directory -Force | Out-Null
    }
    Copy-Item -FromSession $Session -Path (Join-Path $remoteResult.RemoteEvidencePath '*') `
        -Destination $LocalDestination -Recurse -Force
    return $remoteResult
}

function Get-JsonArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Filter
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return , @()
    }
    return , @(Get-ChildItem -LiteralPath $Path -Filter $Filter -File -Recurse | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    })
}

function Get-ComparisonStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Scenario,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ProtocolRowIds,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$PublicRowIds,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ProtocolRows,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$PublicRows,

        [Parameter(Mandatory)]
        [object]$Preflight,

        [Parameter(Mandatory)]
        [string]$ProtocolGateStatus
    )

    if (-not $Preflight.OverallSuccess) {
        $failures = @($Preflight.Checks | Where-Object { $_.Mandatory -and -not $_.Success })
        $failureIds = @($failures | ForEach-Object { $_.CheckId })
        return [PSCustomObject][ordered]@{
            Scenario  = $Scenario
            OldStatus = 'BLOCKED'
            NewStatus = 'BLOCKED_BY_PREFLIGHT'
            RootCause = ($failureIds -join ', ')
            DefinitiveResult = $null
            ProtocolRows = $ProtocolRowIds
            PublicRows   = $PublicRowIds
        }
    }

    $relevantProtocol = @($ProtocolRows | Where-Object ProbeId -in $ProtocolRowIds)
    $failedProtocol = @($relevantProtocol | Where-Object { -not $_.ExpectationMet })
    if ($ProtocolGateStatus -ne 'PASS') {
        $cause = if ($failedProtocol.Count -gt 0) {
            @($failedProtocol | ForEach-Object { "$($_.ProbeId): $($_.ErrorMessage)" }) -join '; '
        }
        else {
            'Public E2E was not started because the complete protocol matrix did not pass.'
        }
        return [PSCustomObject][ordered]@{
            Scenario  = $Scenario
            OldStatus = 'BLOCKED'
            NewStatus = 'FAIL'
            RootCause = $cause
            DefinitiveResult = $null
            ProtocolRows = $ProtocolRowIds
            PublicRows   = $PublicRowIds
        }
    }

    $relevantPublic = @($PublicRows | Where-Object RowId -in $PublicRowIds)
    $relevantPublicIds = @($relevantPublic | ForEach-Object { $_.RowId })
    $missingRows = @($PublicRowIds | Where-Object { $_ -notin $relevantPublicIds })
    $failedPublic = @($relevantPublic | Where-Object { -not $_.ExpectationMet })
    $newStatus = if ($failedProtocol.Count -eq 0 -and $failedPublic.Count -eq 0 -and $missingRows.Count -eq 0) { 'PASS' } else { 'FAIL' }
    $rootCause = if ($newStatus -eq 'PASS') {
        $null
    }
    elseif ($missingRows.Count -gt 0) {
        'Mandatory public rows missing: ' + ($missingRows -join ', ')
    }
    else {
        @($failedPublic | ForEach-Object { "$($_.RowId): $($_.ErrorMessage)" }) -join '; '
    }

    return [PSCustomObject][ordered]@{
        Scenario     = $Scenario
        OldStatus    = 'BLOCKED'
        NewStatus    = $newStatus
        RootCause    = $rootCause
        DefinitiveResult = if ($newStatus -eq 'PASS') { 'All mapped mandatory rows met their expected outcomes.' } else { $null }
        ProtocolRows = $ProtocolRowIds
        PublicRows   = $PublicRowIds
    }
}

foreach ($path in @($EvidencePath, $rerunDirectory)) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

$preflight = $null
$protocolRows = @()
$publicRows = @()
$protocolGateStatus = 'NOT_RUN'
$publicGateStatus = 'NOT_RUN'
$orchestrationError = $null

try {
    Assert-RunnerSession -Session $WindowsRunnerSession -ExpectedComputerName @('MSRunnerWin', 'MiSouleRunnerWin')
    Assert-RunnerSession -Session $LinuxRunnerSession -ExpectedComputerName 'MiSouleRunnerLinux'

    Write-Host 'Gate 1/3: running lab preflight...' -ForegroundColor Cyan
    $preflightPath = Join-Path $rerunDirectory 'preflight'
    try {
        $preflight = & (Join-Path $PSScriptRoot 'Test-LabPrerequisites.ps1') `
            -ResourceGroupName $ResourceGroupName -TagName $TagName -TagValue $TagValue -EvidencePath $preflightPath
    }
    catch {
        $preflightArtifact = Join-Path $preflightPath "preflight-$TagValue.json"
        if (Test-Path -LiteralPath $preflightArtifact) {
            $preflight = Get-Content -LiteralPath $preflightArtifact -Raw | ConvertFrom-Json
        }
        throw
    }

    if (-not $preflight.OverallSuccess) {
        throw 'Preflight returned an unsuccessful result. Protocol and public matrices were not started.'
    }

    Write-Host 'Gate 2/3: running the complete protocol matrix on both runners...' -ForegroundColor Cyan
    $protocolRoot = Join-Path $rerunDirectory 'protocol'
    $windowsProtocol = Invoke-RunnerMatrix -Session $WindowsRunnerSession -Runner Windows -Matrix Protocol `
        -RepositoryPath $WindowsRepositoryPath -LocalDestination (Join-Path $protocolRoot 'windows')
    $linuxProtocol = Invoke-RunnerMatrix -Session $LinuxRunnerSession -Runner Linux -Matrix Protocol `
        -RepositoryPath $LinuxRepositoryPath -LocalDestination (Join-Path $protocolRoot 'linux')
    $protocolRows = Get-JsonArtifact -Path $protocolRoot -Filter 'protocol-probe-*.json'
    $executedProtocolIds = @($protocolRows | ForEach-Object { $_.ProbeId } | Sort-Object -Unique)
    $missingProtocolRows = @($expectedProtocolRows | Where-Object { $_ -notin $executedProtocolIds })
    $protocolGatePassed = $windowsProtocol.ExitCode -eq 0 -and $linuxProtocol.ExitCode -eq 0 -and
        $missingProtocolRows.Count -eq 0 -and @($protocolRows | Where-Object { -not $_.ExpectationMet }).Count -eq 0
    $protocolGateStatus = if ($protocolGatePassed) { 'PASS' } else { 'FAIL' }
    if (-not $protocolGatePassed) {
        throw "Protocol gate failed. Missing rows: $($missingProtocolRows -join ', ')."
    }

    Write-Host 'Gate 3/3: running the complete public E2E matrix on both runners...' -ForegroundColor Cyan
    $publicRoot = Join-Path $rerunDirectory 'public'
    $windowsPublic = Invoke-RunnerMatrix -Session $WindowsRunnerSession -Runner Windows -Matrix Public `
        -RepositoryPath $WindowsRepositoryPath -LocalDestination (Join-Path $publicRoot 'windows')
    $linuxPublic = Invoke-RunnerMatrix -Session $LinuxRunnerSession -Runner Linux -Matrix Public `
        -RepositoryPath $LinuxRepositoryPath -LocalDestination (Join-Path $publicRoot 'linux')
    $publicRows = Get-JsonArtifact -Path $publicRoot -Filter 'AD-PublicPath-*.json'
    $executedPublicIds = @($publicRows | ForEach-Object { $_.RowId } | Sort-Object -Unique)
    $missingPublicRows = @($expectedPublicRows | Where-Object { $_ -notin $executedPublicIds })
    $publicGatePassed = $windowsPublic.ExitCode -eq 0 -and $linuxPublic.ExitCode -eq 0 -and
        $missingPublicRows.Count -eq 0 -and @($publicRows | Where-Object { -not $_.ExpectationMet }).Count -eq 0
    $publicGateStatus = if ($publicGatePassed) { 'PASS' } else { 'FAIL' }
    if (-not $publicGatePassed) {
        throw "Public E2E gate failed. Missing rows: $($missingPublicRows -join ', ')."
    }
}
catch {
    $orchestrationError = $_.Exception.Message
}
finally {
    try {
        if ($null -eq $preflight) {
        $preflight = [PSCustomObject]@{
            OverallSuccess = $false
            Summary = [PSCustomObject]@{ TotalChecks = 0; PassedCount = 0; FailedCount = 1; MandatoryFailedCount = 1 }
            Checks = @([PSCustomObject]@{ CheckId = 'Preflight.Harness'; Mandatory = $true; Success = $false; Actual = $orchestrationError })
        }
    }

    $protocolRoot = Join-Path $rerunDirectory 'protocol'
    $publicRoot = Join-Path $rerunDirectory 'public'
    $protocolRows = Get-JsonArtifact -Path $protocolRoot -Filter 'protocol-probe-*.json'
    $publicRows = Get-JsonArtifact -Path $publicRoot -Filter 'AD-PublicPath-*.json'

    $comparison = @(
        Get-ComparisonStatus -Scenario 'Cross-domain targeting' `
            -ProtocolRowIds @('win-dc03-explicit-implicit-negotiate-ldaps', 'win-dc03-explicit-explicit-basic-ldaps', 'linux-dc03-explicit-explicit-basic-ldaps') `
            -PublicRowIds @('5-win-dc03-explicit-implicit-negotiate-ldaps', '6-win-dc03-explicit-explicit-basic-ldaps', '9-linux-dc03-explicit-explicit-basic-ldaps') `
            -ProtocolRows $protocolRows -PublicRows $publicRows -Preflight $preflight -ProtocolGateStatus $protocolGateStatus
        Get-ComparisonStatus -Scenario 'Cross-forest targeting' `
            -ProtocolRowIds @('win-dc04-explicit-explicit-basic-ldaps', 'linux-dc04-explicit-explicit-basic-ldaps', 'win-dc04-explicit-implicit-negotiate-ldaps-no-trust') `
            -PublicRowIds @('7-win-dc04-explicit-explicit-basic-ldaps', '10-linux-dc04-explicit-explicit-basic-ldaps', 'N3-win-dc04-implicit-implicit-negotiate-ldaps') `
            -ProtocolRows $protocolRows -PublicRows $publicRows -Preflight $preflight -ProtocolGateStatus $protocolGateStatus
        Get-ComparisonStatus -Scenario 'Basic auth over LDAPS' `
            -ProtocolRowIds @('win-dc02-explicit-explicit-basic-ldaps', 'win-dc03-explicit-explicit-basic-ldaps', 'win-dc04-explicit-explicit-basic-ldaps', 'linux-dc02-explicit-explicit-basic-ldaps', 'linux-dc03-explicit-explicit-basic-ldaps', 'linux-dc04-explicit-explicit-basic-ldaps') `
            -PublicRowIds @('4-win-dc02-explicit-explicit-basic-ldaps', '6-win-dc03-explicit-explicit-basic-ldaps', '7-win-dc04-explicit-explicit-basic-ldaps', '8-linux-dc02-explicit-explicit-basic-ldaps', '9-linux-dc03-explicit-explicit-basic-ldaps', '10-linux-dc04-explicit-explicit-basic-ldaps') `
            -ProtocolRows $protocolRows -PublicRows $publicRows -Preflight $preflight -ProtocolGateStatus $protocolGateStatus
        Get-ComparisonStatus -Scenario 'StartTLS negotiation' `
            -ProtocolRowIds @('win-dc02-implicit-implicit-negotiate-starttls', 'linux-dc02-explicit-explicit-basic-starttls', 'win-dc02-explicit-explicit-negotiate-starttls-broken-cert', 'linux-dc02-explicit-explicit-negotiate-starttls-broken-cert') `
            -PublicRowIds @() -ProtocolRows $protocolRows -PublicRows $publicRows -Preflight $preflight -ProtocolGateStatus $protocolGateStatus
        Get-ComparisonStatus -Scenario 'Windows runner integrated auth' `
            -ProtocolRowIds @('win-dc02-implicit-implicit-negotiate-ldaps', 'win-dc02-explicit-implicit-negotiate-ldaps', 'win-dc03-explicit-implicit-negotiate-ldaps') `
            -PublicRowIds @('1-win-dc02-implicit-implicit-negotiate-ldaps', '3-win-dc02-explicit-implicit-negotiate-ldaps', '5-win-dc03-explicit-implicit-negotiate-ldaps') `
            -ProtocolRows $protocolRows -PublicRows $publicRows -Preflight $preflight -ProtocolGateStatus $protocolGateStatus
    )

    $report = [ordered]@{
        SchemaVersion      = 2
        EvidenceType      = 'plan1-plan9-hard-gated-rerun'
        RerunDate          = $rerunStartedAt.ToString('yyyy-MM-dd')
        StartedAt          = $rerunStartedAt.ToString('o')
        CompletedAt        = [datetime]::UtcNow.ToString('o')
        Synthetic          = $false
        SyntheticBasis     = $null
        Plan9Reference     = $plan9Reference
        OldPlan1Reference = $oldPlan1Reference
        OverallStatus      = if ($preflight.OverallSuccess -and $protocolGateStatus -eq 'PASS' -and $publicGateStatus -eq 'PASS') { 'PASS' } else { 'FAIL' }
        OrchestrationError = $orchestrationError
        ExecutionOrder     = @('Preflight', 'ProtocolProbeMatrix', 'PublicE2EMatrix', 'Plan1Comparison')
        Preflight          = [ordered]@{
            Status  = if ($preflight.OverallSuccess) { 'PASS' } else { 'FAIL' }
            Summary = $preflight.Summary
            Checks  = $preflight.Checks
        }
        ProtocolProbes     = [ordered]@{
            Status          = $protocolGateStatus
            ExpectedRowCount = $expectedProtocolRows.Count
            ExecutedRowCount = @($protocolRows).Count
            ExpectedRowIds  = $expectedProtocolRows
            ExecutedRowIds  = @($protocolRows | ForEach-Object { $_.ProbeId } | Sort-Object -Unique)
            Rows            = $protocolRows
        }
        PublicE2EMatrix    = [ordered]@{
            Status          = $publicGateStatus
            ExpectedRowCount = $expectedPublicRows.Count
            ExecutedRowCount = @($publicRows).Count
            ExpectedRowIds  = $expectedPublicRows
            ExecutedRowIds  = @($publicRows | ForEach-Object { $_.RowId } | Sort-Object -Unique)
            Rows            = $publicRows
            ReportArtifacts = @($publicRows | ForEach-Object { $_.Reports } | Where-Object { $_ } | Sort-Object -Unique)
        }
        ComparisonWithOldPlan1 = $comparison
        RemainingBlockers  = @($comparison | Where-Object NewStatus -ne PASS | ForEach-Object {
            [ordered]@{ Scenario = $_.Scenario; Status = $_.NewStatus; ProcessFailure = $_.RootCause }
        })
        ArtifactDirectory  = $rerunDirectory
        CertificationNote  = $null
    }
        Write-RerunJson -InputObject $report -Path $reportPath
        Write-Host "Unified rerun report: $reportPath" -ForegroundColor Cyan
    }
    catch {
        $reportFailure = $_.Exception.Message
        $report = [ordered]@{
            SchemaVersion      = 2
            EvidenceType      = 'plan1-plan9-hard-gated-rerun'
            RerunDate          = $rerunStartedAt.ToString('yyyy-MM-dd')
            StartedAt          = $rerunStartedAt.ToString('o')
            CompletedAt        = [datetime]::UtcNow.ToString('o')
            Synthetic          = $false
            SyntheticBasis     = $null
            Plan9Reference     = $plan9Reference
            OldPlan1Reference = $oldPlan1Reference
            OverallStatus      = 'FAIL'
            OrchestrationError = $orchestrationError
            ReportError        = $reportFailure
            ExecutionOrder     = @('Preflight', 'ProtocolProbeMatrix', 'PublicE2EMatrix', 'Plan1Comparison')
            RemainingBlockers  = @([ordered]@{
                Scenario       = 'Rerun report generation'
                Status         = 'FAIL'
                ProcessFailure = $reportFailure
            })
            ArtifactDirectory  = $rerunDirectory
            CertificationNote  = $null
        }
        Write-RerunJson -InputObject $report -Path $reportPath
        Write-Host "Fallback rerun report: $reportPath" -ForegroundColor Yellow
    }
}

if ($report.OverallStatus -ne 'PASS') {
    throw "Plan 1 rerun failed. See '$reportPath'."
}

return [PSCustomObject]$report

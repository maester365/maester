function Get-MtZtaInstance {
    <#
    .SYNOPSIS
    Returns one ZTA instance per result of the Microsoft Zero Trust Assessment.

    .DESCRIPTION
    Instance source of the ZTA family. Reads the assessment's ZeroTrustAssessmentReport.json from the
    ZeroTrustAssessment.ReportPath setting when one is set (import), otherwise runs the assessment in a child
    PowerShell process (collect), then returns one instance per test result. Skips the whole family, with the
    reason, when neither is possible.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $reportPath = [string](Get-MtSetting -Name 'ZeroTrustAssessment.ReportPath' -Default '')
    $collected = $null
    if ([string]::IsNullOrWhiteSpace($reportPath)) {
        $collected = Invoke-MtZtaCollection
        $reportPath = $collected.ReportPath
    }

    try {
        $report = Read-MtZtaReport -Path $reportPath
        $context = Get-MgContext
        if ($context -and $context.TenantId -and $report.TenantId -and $report.TenantId -ne $context.TenantId) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The Zero Trust Assessment report at $reportPath is for tenant $($report.TenantId), but Maester is connected to tenant $($context.TenantId)."
        }

        $maxAgeDays = [int](Get-MtSetting -Name 'ZeroTrustAssessment.MaxReportAgeDays' -Default 7)
        $executedAt = [datetime]::MinValue
        if ($maxAgeDays -gt 0 -and [datetime]::TryParse([string]$report.ExecutedAt, [ref]$executedAt) -and
            $executedAt.ToUniversalTime() -lt [datetime]::UtcNow.AddDays(-$maxAgeDays)) {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The Zero Trust Assessment report at $reportPath was written on $($executedAt.ToString('yyyy-MM-dd')), more than $maxAgeDays days ago. Run Invoke-ZtAssessment again, or raise the ZeroTrustAssessment.MaxReportAgeDays setting."
        }

        Add-MtZtaReportAttachment -ReportPath $reportPath
        ConvertTo-MtZtaInstance -Report $report
    } finally {
        # A collection into a temporary folder leaves nothing behind: the export holds raw tenant data.
        if ($collected -and $collected.Temporary -and (Test-Path -LiteralPath $collected.OutputPath)) {
            Remove-Item -LiteralPath $collected.OutputPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Add-MtZtaReportAttachment {
    <#
    .SYNOPSIS
    Embeds the assessment's own HTML report in the Maester report, opened with one click.

    .DESCRIPTION
    The assessment writes ZeroTrustAssessmentReport.html in the folder given to Invoke-ZtAssessment -Path, beside
    its zt-export folder. It is read before a temporary output folder is deleted. Nothing is attached when the
    report is not there (an imported report file copied on its own), when the ZeroTrustAssessment.EmbedReport
    setting is false, or on a Maester version without Add-MtReportAttachment.
    #>
    [CmdletBinding()]
    param(
        # The report file, the assessment's output folder, or its zt-export folder.
        [Parameter(Mandatory)] [string] $ReportPath
    )

    if (-not [bool](Get-MtSetting -Name 'ZeroTrustAssessment.EmbedReport' -Default $true)) { return }
    if (-not (Get-Command -Name Add-MtReportAttachment -ErrorAction Ignore)) { return }

    $folder = if (Test-Path -LiteralPath $ReportPath -PathType Container) { $ReportPath } else { Split-Path -Path $ReportPath -Parent }
    if (-not $folder) { return }
    $html = @(
        (Join-Path $folder 'ZeroTrustAssessmentReport.html'),
        (Join-Path (Split-Path -Path $folder -Parent) 'ZeroTrustAssessmentReport.html')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    if ($html) {
        Add-MtReportAttachment -Name 'Zero Trust Assessment' -Path $html
    } else {
        Write-Verbose "No ZeroTrustAssessmentReport.html next to $ReportPath, so the assessment's own report is not embedded."
    }
}

function Read-MtZtaReport {
    <#
    .SYNOPSIS
    Reads ZeroTrustAssessmentReport.json from a file, or from a folder the assessment wrote.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The report file, the assessment's output folder, or its zt-export folder.
        [Parameter(Mandatory)] [string] $Path
    )

    $file = $Path
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $file = @(
            (Join-Path $Path 'ZeroTrustAssessmentReport.json'),
            (Join-Path -Path $Path -ChildPath 'zt-export' -AdditionalChildPath 'ZeroTrustAssessmentReport.json')
        ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
    if (-not $file -or -not (Test-Path -LiteralPath $file -PathType Leaf)) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "No Zero Trust Assessment report was found at $Path. Point the ZeroTrustAssessment.ReportPath setting at ZeroTrustAssessmentReport.json, or clear it to let Maester run the assessment."
    }

    $report = Get-Content -LiteralPath $file -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
    if (-not $report.PSObject.Properties['Tests']) {
        throw "$file is not a Zero Trust Assessment report: it has no Tests list."
    }
    $report
}

function ConvertTo-MtZtaInstance {
    <#
    .SYNOPSIS
    Turns the Tests of a Zero Trust Assessment report into ZTA instances.

    .DESCRIPTION
    The instance suffix is the assessment's test ID. A test that writes several rows under one ID (the Defender
    for Cloud recommendations do) gets a suffix made from a hash of each row's title, so a row keeps its ID from
    one run to the next. Rows that share a title as well are numbered in report order. Planned tests, which the assessment lists but has not built, are left out.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # A report read by Read-MtZtaReport.
        [Parameter(Mandatory)] $Report
    )

    $severity = @{ High = 'High'; Medium = 'Medium'; Low = 'Low' }
    $rows = @($Report.Tests | Where-Object { $_ -and $_.TestStatus -ne 'Planned' -and $_.TestSkipped -ne 'UnderConstruction' })
    $repeated = @($rows | Group-Object -Property { [string]$_.TestId } | Where-Object Count -gt 1 | ForEach-Object Name)
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        foreach ($row in $rows) {
            $id = ([string]$row.TestId -replace '[^A-Za-z0-9._-]', '_') -replace '^[^A-Za-z0-9]+', ''
            if (-not $id) { continue }
            if ([string]$row.TestId -in $repeated) {
                $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes([string]$row.TestTitle))
                $id = '{0}.{1}' -f $id, ([System.Convert]::ToHexString($hash).Substring(0, 10).ToLowerInvariant())
            }
            $unique = $id
            for ($n = 2; -not $seen.Add($unique); $n++) { $unique = "$id.$n" }
            $id = $unique
            $tags = @('ZeroTrust') + @(@($row.TestPillar) | Where-Object { $_ } | ForEach-Object { "ZeroTrust.$_" })
            $instance = [ordered]@{
                Id    = $id
                Title = ([string]$row.TestTitle -replace '\s+', ' ').Trim()
                Tag   = $tags
                Data  = $row
            }
            if ($severity.ContainsKey([string]$row.TestRisk)) { $instance.Severity = $severity[[string]$row.TestRisk] }
            [pscustomobject]$instance
        }
    } finally {
        $sha.Dispose()
    }
}

function Invoke-MtZtaCollection {
    <#
    .SYNOPSIS
    Runs the Microsoft Zero Trust Assessment in a child PowerShell process and returns where it wrote its report.

    .DESCRIPTION
    The assessment loads its own pinned versions of the Microsoft Graph, Exchange Online and Az modules and of
    MSAL, which cannot share a process with the versions Maester has already loaded. So it runs in its own
    pwsh process, signs in there with Connect-ZtAssessment, and Maester reads the report it writes.

    The child's output is read line by line and shown with Write-MtTestOutput: in the dashboard of an
    interactive run it scrolls in a box in the main column, elsewhere it is written to the host. The
    assessment runs with -ShowLog (the ZeroTrustAssessment.ShowLog setting, on by default), so the box shows
    the tests it runs, and its progress bars become one line at the bottom of the box that updates in place.

    The child signs in to the tenant Maester is connected to. When Maester is connected to Graph app-only with a
    certificate, the child uses the same app and certificate; otherwise it signs in interactively. The
    ZeroTrustAssessment.Connect setting passes any other Connect-ZtAssessment parameters.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $module = Get-Module -Name ZeroTrustAssessment -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $module) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'The ZeroTrustAssessment module is not installed. Run Install-Module ZeroTrustAssessment -Scope CurrentUser, or set ZeroTrustAssessment.ReportPath to a report from an earlier run.'
    }

    $outputPath = [string](Get-MtSetting -Name 'ZeroTrustAssessment.OutputPath' -Default '')
    $temporary = [string]::IsNullOrWhiteSpace($outputPath)
    if ($temporary) {
        $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("maester-zta-{0}" -f [guid]::NewGuid().ToString('n'))
    } elseif ((Test-Path -LiteralPath $outputPath) -and @(Get-ChildItem -LiteralPath $outputPath -Force).Count -gt 0) {
        # Invoke-ZtAssessment deletes a non-empty output folder, so each run gets its own folder under it.
        $outputPath = Join-Path $outputPath (Get-Date -Format 'yyyyMMdd-HHmmss')
    }
    $null = New-Item -ItemType Directory -Path $outputPath -Force

    $connect = [ordered]@{}
    $context = Get-MgContext
    if ($context) {
        if ($context.TenantId) { $connect.TenantId = $context.TenantId }
        if ([string]$context.AuthType -eq 'AppOnly' -and $context.CertificateThumbprint) {
            $connect.ClientId = $context.ClientId
            $connect.Certificate = $context.CertificateThumbprint
        }
    }
    $connectSetting = Get-MtSetting -Name 'ZeroTrustAssessment.Connect' -Default $null
    if ($connectSetting) {
        foreach ($property in $connectSetting.PSObject.Properties) { $connect[$property.Name] = $property.Value }
    }

    $assessment = [ordered]@{
        Path             = $outputPath
        Pillar           = [string](Get-MtSetting -Name 'ZeroTrustAssessment.Pillar' -Default 'All')
        NoBrowser        = $true
        DisableTelemetry = [bool](Get-MtSetting -Name 'ZeroTrustAssessment.DisableTelemetry' -Default $true)
        ShowLog          = [bool](Get-MtSetting -Name 'ZeroTrustAssessment.ShowLog' -Default $true)
    }
    $days = Get-MtSetting -Name 'ZeroTrustAssessment.Days' -Default $null
    if ($days) { $assessment.Days = [int]$days }
    $tests = @(Get-MtSetting -Name 'ZeroTrustAssessment.Tests' -Default @()) | Where-Object { $_ }
    if ($tests.Count -gt 0) { $assessment.Tests = [string[]]$tests }

    # The assessment reads emergency access accounts from its own configuration file, in the same shape as
    # Maester's GlobalSettings.EmergencyAccessAccounts.
    $emergencyAccounts = @(Get-MtSetting -Name 'EmergencyAccessAccounts' -Default @()) | Where-Object { $_ }
    $configurationFile = $null
    if ($emergencyAccounts.Count -gt 0) {
        $configurationFile = Join-Path ([System.IO.Path]::GetTempPath()) ("maester-zta-config-{0}.json" -f [guid]::NewGuid().ToString('n'))
        @{ GlobalSettings = @{ EmergencyAccessAccounts = $emergencyAccounts } } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configurationFile -Encoding utf8
        $assessment.ConfigurationFile = $configurationFile
    }

    $request = Join-Path ([System.IO.Path]::GetTempPath()) ("maester-zta-request-{0}.json" -f [guid]::NewGuid().ToString('n'))
    [ordered]@{ ModulePath = $module.Path; Connect = $connect; Assessment = $assessment } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $request -Encoding utf8

    # The child reads its parameters from the request file, so nothing from the config is put on a command line.
    # Its output is read by Maester as lines of plain text. Its progress bars cannot be drawn there, so each
    # change of one is written as a line that starts with a marker (the module's own Write-Progress calls find
    # this function before the cmdlet), which Maester shows as one line that updates in place.
    $progressMarker = "[maester-progress-$([guid]::NewGuid().ToString('n').Substring(0, 8))] "
    $script = @'
param([string] $RequestPath, [string] $ProgressMarker)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$PSStyle.OutputRendering = 'PlainText'
function global:Write-Progress {
    # Not an advanced function: a parameter it does not declare goes to $args instead of failing the call.
    param([string] $Activity, [string] $Status, [int] $Id, [int] $PercentComplete = -1, [string] $CurrentOperation, [switch] $Completed)
    if ($Completed) {
        # An empty line of progress takes the line away.
        if ($global:__MtZtaProgress) { [Console]::Out.WriteLine($ProgressMarker) }
        $global:__MtZtaProgress = $null
        return
    }
    $text = @($Activity, $Status, $CurrentOperation) | Where-Object { $_ }
    $text = $text -join ': '
    if ($PercentComplete -ge 0) { $text += " ($PercentComplete%)" }
    if ($text -and $text -ne $global:__MtZtaProgress) {
        $global:__MtZtaProgress = $text
        [Console]::Out.WriteLine($ProgressMarker + $text)
    }
}
$request = Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json -AsHashtable
Import-Module -Name $request.ModulePath
$connect = $request.Connect
Connect-ZtAssessment @connect
$assessment = $request.Assessment
Invoke-ZtAssessment @assessment
'@
    $scriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("maester-zta-run-{0}.ps1" -f [guid]::NewGuid().ToString('n'))
    Set-Content -LiteralPath $scriptPath -Value $script -Encoding utf8

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($argument in '-NoProfile', '-File', $scriptPath, '-RequestPath', $request, '-ProgressMarker', $progressMarker) { $startInfo.ArgumentList.Add($argument) }
    $startInfo.UseShellExecute = $false
    # The child must not write to the console itself: while Maester's dashboard has the screen, that would
    # draw over it. Maester shows what it writes instead.
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    # The last lines it wrote, for the error when it fails.
    $tail = [System.Collections.Generic.Queue[string]]::new()
    $show = {
        param([string] $Line)
        $progress = $Line.StartsWith($progressMarker)
        if ($progress) {
            $Line = $Line.Substring($progressMarker.Length)
        } elseif ($Line.Trim()) {
            $tail.Enqueue([Maester.Engine.MtConsoleRenderer]::OutputText($Line))
            if ($tail.Count -gt 15) { $null = $tail.Dequeue() }
        }
        Write-MtTestOutput -InputObject $Line -Progress:$progress
    }
    $process = $null
    try {
        Write-MtTestOutput -Title "Microsoft Zero Trust Assessment $($module.Version)" -InputObject 'Running the assessment in a separate PowerShell process. This can take an hour or more on a large tenant.'
        $process = [System.Diagnostics.Process]::Start($startInfo)
        $readers = @($process.StandardOutput, $process.StandardError)
        $reads = [System.Threading.Tasks.Task[]]@($readers[0].ReadLineAsync(), $readers[1].ReadLineAsync())
        $exited = $null
        while ($reads[0] -or $reads[1]) {
            # Wait in short steps so a stop request (a timeout or Ctrl+C) is seen between them.
            $null = [System.Threading.Tasks.Task]::WaitAny([System.Threading.Tasks.Task[]]@($reads | Where-Object { $_ }), 1000)
            for ($i = 0; $i -lt 2; $i++) {
                if (-not $reads[$i] -or -not $reads[$i].IsCompleted) { continue }
                $line = $reads[$i].GetAwaiter().GetResult()
                if ($null -eq $line) { $reads[$i] = $null; continue }
                $reads[$i] = $readers[$i].ReadLineAsync()
                & $show $line
            }
            # A process the child started can keep its output open after it ends: give it a few seconds.
            if ($process.HasExited) {
                if (-not $exited) { $exited = [System.Diagnostics.Stopwatch]::StartNew() }
                elseif ($exited.Elapsed.TotalSeconds -gt 5) { break }
            }
        }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            $where = if ($temporary) { '' } else { " Its log is in $outputPath." }
            $last = if ($tail.Count -gt 0) { " Its last lines:`n" + ($tail.ToArray() -join "`n") } else { '' }
            throw "The Zero Trust Assessment ended with exit code $($process.ExitCode).$where$last"
        }
    } finally {
        # Stopping the Maester run (a timeout or Ctrl+C) stops the assessment too.
        if ($process -and -not $process.HasExited) { $process.Kill($true) }
        Write-MtTestOutput -Complete
        Remove-Item -LiteralPath $request, $scriptPath -Force -ErrorAction SilentlyContinue
        if ($configurationFile) { Remove-Item -LiteralPath $configurationFile -Force -ErrorAction SilentlyContinue }
    }

    [pscustomobject]@{
        OutputPath = $outputPath
        ReportPath = Join-Path -Path $outputPath -ChildPath 'zt-export' -AdditionalChildPath 'ZeroTrustAssessmentReport.json'
        Temporary  = $temporary
    }
}

function Test-MtZeroTrustAssessment {
    [MaesterTest(
        Id = 'ZTA',
        Title = 'Microsoft Zero Trust Assessment',
        Product = 'Zero Trust Assessment',
        Service = 'Graph',
        LongRunning = $true,
        InstanceSource = 'Get-MtZtaInstance',
        Tag = 'ZeroTrust',
        Author = 'merill',
        HelpUrl = 'https://aka.ms/zerotrust/assessment'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # One result of the Zero Trust Assessment, supplied by the engine.
        $Instance
    )

    $row = $Instance.Data
    $detail = @{
        Description = [string]$row.TestDescription
        Result      = [string]$row.TestResult
    }

    # Skip reasons the assessment shares with Maester keep Maester's wording; the rest keep the assessment's.
    $sharedSkipReason = @(
        'NotApplicable', 'NotSupported', 'NotDotGovDomain', 'NotConnectedAzure', 'NotConnectedExchange',
        'NotConnectedSecurityCompliance', 'NotLicensedEntraIDP1', 'NotLicensedEntraIDP2',
        'NotLicensedEntraIDGovernance', 'NotLicensedEntraWorkloadID', 'NotLicensedIntune'
    )

    switch ([string]$row.TestStatus) {
        'Passed' {
            Add-MtTestResultDetail @detail
            return $true
        }
        'Failed' {
            Add-MtTestResultDetail @detail
            return $false
        }
        'Investigate' {
            Add-MtTestResultDetail @detail -Investigate
            return $true
        }
        'Skipped' {
            $code = [string]$row.TestSkipped
            if ($code -in $sharedSkipReason) {
                Add-MtTestResultDetail -Description $detail.Description -SkippedBecause $code
            }
            $reason = if ($row.SkippedReason) { [string]$row.SkippedReason } elseif ($code) { $code } else { 'Skipped by the Zero Trust Assessment.' }
            Add-MtTestResultDetail -Description $detail.Description -SkippedBecause Custom -SkippedCustomReason $reason
        }
        default {
            # Error, or a status this version of the pack does not know.
            Add-MtTestResultDetail @detail -SkippedBecause Error
        }
    }
}

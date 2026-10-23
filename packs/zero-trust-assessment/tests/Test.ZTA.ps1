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

    The child also reports where the assessment is, read from the progress the module keeps for its own
    progress page and from the progress logs it writes: the stage, the exports or tests done of how many,
    the ones running, and each one that fails. It writes these as ##maester[progress] and ##maester[error]
    lines, which Write-MtTestOutput shows at the top of the box (see Write-MtTestProgress).

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
    # The titles of the assessment's tests, from the pack's catalog, for the tests the progress lists by ID.
    $titles = @{}
    $catalogPath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'catalog.json'
    if (Test-Path -LiteralPath $catalogPath) {
        foreach ($entry in @((Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json).Tests)) { $titles[[string]$entry.TestId] = [string]$entry.Title }
    }
    [ordered]@{ ModulePath = $module.Path; Connect = $connect; Assessment = $assessment; Titles = $titles } |
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
# The assessment keeps where it is (its stage, the items done, what each export or test is doing) in a
# dictionary that its own progress page reads, and writes a line to a progress log for each export, database
# table and test that starts, ends or fails, with its time. A second runspace reads both every second and
# reports them to Maester as ##maester lines, which Maester shows at the top of its output box: the stages, the
# counts, and each export or test with its status and time, the way the dashboard shows Maester's own tests.
# Another version of the module that keeps neither reports nothing.
$progressState = $null
try { $progressState = Get-PSFDynamicContentObject -Name 'ZtAssessment.ProgressState' -ErrorAction Stop } catch { $progressState = $null }
$reporter = [powershell]::Create()
$null = $reporter.AddScript({
    param($State, [string] $OutputPath, $Titles)
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    # The stages of the assessment, short enough to draw all six on one line.
    $stages = @('Export', 'Tests', 'Tenant info', 'Results', 'Report data', 'HTML report')
    $kinds = [ordered]@{ '1-export_progress.log' = 'export'; '2-database_progress.log' = 'database'; '3-test_progress.log' = 'tests' }
    $offsets = @{}
    $items = @{}
    $reported = [System.Collections.Generic.HashSet[string]]::new()
    $lastKind = $null
    $last = $null
    while ($true) {
        try {
            $now = Get-Date
            # The newest folder of logs is this run's: read the lines added to its progress logs since the last time.
            $logs = Get-ChildItem -LiteralPath (Join-Path $OutputPath 'zt-export' -AdditionalChildPath 'logs') -Directory -ErrorAction SilentlyContinue |
                Sort-Object -Property Name | Select-Object -Last 1
            if ($logs) {
                foreach ($file in $kinds.Keys) {
                    $path = Join-Path $logs.FullName $file
                    if (-not [System.IO.File]::Exists($path)) { continue }
                    $stream = [System.IO.FileStream]::new($path, 'Open', 'Read', 'ReadWrite, Delete')
                    try {
                        $at = [long]$offsets[$path]
                        if ($stream.Length -le $at) { continue }
                        $null = $stream.Seek($at, 'Begin')
                        $bytes = [byte[]]::new($stream.Length - $at)
                        $read = $stream.Read($bytes, 0, $bytes.Length)
                        $text = [System.Text.Encoding]::UTF8.GetString($bytes, 0, $read)
                        # Only whole lines: the rest is read again when it has ended.
                        $end = $text.LastIndexOf("`n")
                        if ($end -lt 0) { continue }
                        $offsets[$path] = $at + [System.Text.Encoding]::UTF8.GetByteCount($text.Substring(0, $end + 1))
                        $kind = $kinds[$file]
                        foreach ($line in $text.Substring(0, $end).Split("`n")) {
                            if ($line -notmatch '^(\S+ \S+)\s+(STARTED|WAITING|INPROGRESS|COMPLETED|FAILED|ERROR|TIMEDOUT)\s+(\S+)(?:\s+(\d\d:\d\d:\d\d\.\d+))?\s*(.*)$') { continue }
                            $action = $Matches[2]
                            $name = $Matches[3]
                            $duration = $Matches[4]
                            $message = $Matches[5].Trim() -replace '^Error:\s*', ''
                            $time = [datetime]::MinValue
                            $null = [datetime]::TryParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss.fff', $culture, 'None', [ref]$time)
                            $lastKind = $kind
                            $key = "$kind|$name"
                            $item = $items[$key]
                            if (-not $item -or $action -eq 'STARTED' -and $item.Status -notin 'Running', 'Waiting') {
                                $item = @{ Kind = $kind; Name = $name; Start = $time; End = $null; Status = 'Running'; Detail = ''; Seconds = -1 }
                                $items[$key] = $item
                                $null = $reported.Remove($key)
                            }
                            switch ($action) {
                                'WAITING' { $item.Status = 'Waiting'; $item.Detail = if ($message -like 'dependency:*') { "waiting for $($message.Substring(11))" } else { $message } }
                                'INPROGRESS' { $item.Status = 'Running'; if ($message) { $item.Detail = $message } }
                                default {
                                    if ($action -eq 'STARTED') { break }
                                    $item.End = $time
                                    $item.Status = switch ($action) { 'COMPLETED' { 'Passed' } 'TIMEDOUT' { 'TimedOut' } default { 'Failed' } }
                                    $item.Detail = if ($action -eq 'COMPLETED') { '' } else { $message }
                                    $span = [timespan]::Zero
                                    $item.Seconds = if ($duration -and [timespan]::TryParse($duration, $culture, [ref]$span)) { $span.TotalSeconds }
                                    elseif ($item.Start -ne [datetime]::MinValue) { ($time - $item.Start).TotalSeconds } else { -1 }
                                    if ($action -ne 'COMPLETED') {
                                        $what = switch ($kind) { 'export' { 'Export' } 'database' { 'Import of' } default { 'Test' } }
                                        $label = if ($kind -eq 'tests' -and $Titles -and $Titles[$name]) { "$name $($Titles[$name])" } else { $name }
                                        $verb = if ($action -eq 'TIMEDOUT') { 'timed out' } else { 'failed' }
                                        [Console]::Out.WriteLine('##maester[error] ' + "$what $label $verb" + $(if ($message) { ": $message" } else { '' }))
                                    }
                                }
                            }
                        }
                    } finally { $stream.Dispose() }
                }
            }

            $value = if ($State) { $State.Value } else { $null }
            $stage = if ($value -and $value.ContainsKey('_stage')) { [string]$value['_stage'] } else { $null }
            $kind = switch ($stage) { 'export' { 'export' } 'database' { 'database' } 'tests' { 'tests' } $null { $lastKind } default { $null } }
            if (-not $stage -and -not $kind) { Start-Sleep -Milliseconds 1000; continue }

            # The exports or tests of the stage: those running, then those that finished, the newest last.
            $mine = @($items.Values | Where-Object { $_.Kind -eq $kind })
            $running = @($mine | Where-Object { $_.Status -in 'Running', 'Waiting' } | Sort-Object -Property { $_.Start })
            $finished = @($mine | Where-Object { $_.Status -notin 'Running', 'Waiting' } | Sort-Object -Property { $_.End })
            $shown = [System.Collections.Generic.List[object]]::new()
            foreach ($item in $running) {
                $detail = $item.Detail
                $worker = $null
                if ($value -and $item.Status -eq 'Running' -and $value.TryGetValue("worker_$($item.Name)", [ref]$worker) -and $worker -and $worker.Detail) { $detail = [string]$worker.Detail }
                $shown.Add(@{ Item = $item; Detail = $detail; Seconds = if ($item.Start -ne [datetime]::MinValue) { [math]::Floor(($now - $item.Start).TotalSeconds) } else { -1 } })
            }
            # The last eight that finished, and every one that finished since the last report, so that none is missed.
            $recent = @($finished | Select-Object -Last 8)
            foreach ($item in $finished) {
                $key = "$($item.Kind)|$($item.Name)"
                if ($reported.Add($key) -or $recent -contains $item) { $shown.Add(@{ Item = $item; Detail = $item.Detail; Seconds = $item.Seconds }) }
            }
            # A step of the stage that writes no log, such as creating the database, is shown from the dictionary.
            if ($running.Count -eq 0 -and $value) {
                foreach ($key in @($value.Keys)) {
                    $worker = $null
                    if ($key -like 'worker_*' -and $value.TryGetValue($key, [ref]$worker) -and $worker -and [string]$worker.Status -eq 'Running') {
                        $started = [datetime]::MinValue
                        $seconds = if ([datetime]::TryParse([string]$worker.StartedAt, $culture, 'RoundtripKind', [ref]$started)) { [math]::Floor(($now - $started.ToLocalTime()).TotalSeconds) } else { -1 }
                        $shown.Add(@{ Item = @{ Kind = ''; Name = [string]$worker.Name; Status = 'Running' }; Detail = [string]$worker.Detail; Seconds = $seconds })
                    }
                }
            }
            $list = foreach ($entry in $shown) {
                $item = $entry.Item
                if ($item.Kind -eq 'tests') { $id = "ZTA.$($item.Name)"; $title = if ($Titles) { [string]$Titles[$item.Name] } else { '' } }
                else { $id = $item.Name; $title = '' }
                [ordered]@{ id = $id; title = $title; status = $item.Status; detail = [string]$entry.Detail; seconds = $entry.Seconds }
            }

            $counted = $value -and $stage -in 'export', 'tests' -and [int]$value['_totalItems'] -gt 0
            $snapshot = [ordered]@{
                stages      = $stages
                stage       = if ($value) { [string]$value['_stageName'] } else { switch ($kind) { 'export' { 'Exporting Tenant Data' } 'database' { 'Importing Data into Database' } default { 'Running Tests' } } }
                stageNumber = if ($value) { [int]$value['_stageNumber'] } elseif ($kind -eq 'tests') { 2 } else { 1 }
                stageCount  = $stages.Count
                completed   = if ($counted) { [int]$value['_completedItems'] } else { @($finished | Where-Object { $_.Status -eq 'Passed' }).Count }
                total       = if ($counted) { [int]$value['_totalItems'] } else { 0 }
                failed      = if ($counted) { [int]$value['_failedItems'] } else { @($finished | Where-Object { $_.Status -ne 'Passed' }).Count }
                running     = if ($counted) { [int]$value['_inProgressItems'] } else { $running.Count }
                items       = @($list)
            }
            if ($stage -eq 'done') { $snapshot.stageNumber = $stages.Count + 1; $snapshot.items = @(); $snapshot.running = 0 }
            $json = $snapshot | ConvertTo-Json -Compress -Depth 4
            if ($json -ne $last) {
                $last = $json
                [Console]::Out.WriteLine('##maester[progress] ' + $json)
            }
        } catch {
            # Reporting progress must never stop the assessment.
            $null = $_
        }
        Start-Sleep -Milliseconds 1000
    }
}).AddArgument($progressState).AddArgument([string]$request.Assessment.Path).AddArgument($request.Titles)
$reporting = $reporter.BeginInvoke()
try {
    $connect = $request.Connect
    Connect-ZtAssessment @connect
    $assessment = $request.Assessment
    Invoke-ZtAssessment @assessment
} finally {
    $reporter.Stop()
    $reporter.Dispose()
}
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
        } elseif ($Line.Trim() -and -not $Line.StartsWith('##maester[progress]')) {
            $tail.Enqueue([Maester.Engine.MtConsoleRenderer]::OutputText($Line))
            if ($tail.Count -gt 15) { $null = $tail.Dequeue() }
        }
        Write-MtTestOutput -InputObject $Line -Progress:$progress
    }
    $process = $null
    $completed = $false
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
        $completed = $true
    } finally {
        # Stopping the Maester run (a timeout or Ctrl+C) stops the assessment too.
        if ($process -and -not $process.HasExited) { $process.Kill($true); $null = $process.WaitForExit(5000) }
        Write-MtTestOutput -Complete
        Remove-Item -LiteralPath $request, $scriptPath -Force -ErrorAction SilentlyContinue
        if ($configurationFile) { Remove-Item -LiteralPath $configurationFile -Force -ErrorAction SilentlyContinue }
        # The export holds tenant data. Get-MtZtaInstance removes it after a run that completed; this removes what a failed or stopped run left.
        if ($temporary -and -not $completed) { Remove-Item -LiteralPath $outputPath -Recurse -Force -ErrorAction SilentlyContinue }
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

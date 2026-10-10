function Format-MtConsoleText {
    <#
    .SYNOPSIS
    Wraps text in the ANSI colour for a style, when the console mode uses colour.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)] [AllowEmptyString()] [string] $Text,
        [Parameter()] [ValidateSet('Passed', 'Failed', 'Error', 'Investigate', 'Dim', 'Bold', 'Accent')] [string] $Style = 'Dim',
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    if (-not $Console -or -not $Console.Ansi -or $Text -eq '') { return $Text }
    $sgr = switch ($Style) { 'Passed' { '32' } 'Failed' { '31' } 'Error' { '33' } 'Investigate' { '35' } 'Dim' { '2' } 'Bold' { '1' } 'Accent' { '36' } }
    "$([char]27)[$($sgr)m$Text$([char]27)[0m"
}

function Format-MtResultLabel {
    <#
    .SYNOPSIS
    Returns the symbol and word for a result: never colour alone, so it reads the same without colour.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Result,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    if ($Console -and $Console.Unicode) {
        $symbol = switch ($Result) { 'Passed' { '✓' } 'Failed' { '✗' } 'Error' { '!' } 'Investigate' { '?' } default { '–' } }
        return "$symbol $Result"
    }
    $word = switch ($Result) { 'Passed' { 'PASS' } 'Failed' { 'FAIL' } 'Error' { 'ERROR' } 'Investigate' { 'INVESTIGATE' } 'Skipped' { 'SKIP' } 'NotRun' { 'NOTRUN' } default { $Result.ToUpperInvariant() } }
    "[$word]"
}

function Format-MtDuration {
    <#
    .SYNOPSIS
    Formats a duration for the console: 120 ms, 2.4 s, 1:05.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory, Position = 0)] [timespan] $Duration)
    $inv = [cultureinfo]::InvariantCulture
    if ($Duration.TotalSeconds -lt 1) { return '{0:0} ms' -f $Duration.TotalMilliseconds }
    if ($Duration.TotalMinutes -lt 1) { return $Duration.TotalSeconds.ToString('0.0', $inv) + ' s' }
    if ($Duration.TotalHours -lt 1) { return '{0}:{1:00}' -f [int][math]::Floor($Duration.TotalMinutes), $Duration.Seconds }
    '{0}:{1:00}:{2:00}' -f [int][math]::Floor($Duration.TotalHours), $Duration.Minutes, $Duration.Seconds
}

function Write-MtRunHeartbeat {
    <#
    .SYNOPSIS
    Writes a progress line in Stream and Plain mode, so CI logs show the run is alive.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int] $Done,
        [Parameter(Mandatory)] [int] $Total,
        [Parameter()] [int] $Failed,
        [Parameter()] [timespan] $Elapsed,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    $percent = if ($Total -gt 0) { [int](100 * $Done / $Total) } else { 0 }
    Write-MtConsoleLine (Format-MtConsoleText "[Maester] $Done/$Total tests ($percent%), $Failed failed or errored, $(Format-MtDuration $Elapsed)" -Style Dim -Console $Console)
    if ($Console -and $Console.CI -eq 'AzureDevOps') { Write-MtConsoleLine "##vso[task.setprogress value=$percent;]Maester" }
}

function Write-MtCIGroup {
    <#
    .SYNOPSIS
    Starts or ends a collapsible log group on GitHub Actions or Azure Pipelines.
    #>
    [CmdletBinding()]
    param(
        [Parameter()] [string] $Name,
        [Parameter()] [switch] $End,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    switch ($Console.CI) {
        'GitHubActions' { Write-MtConsoleLine $(if ($End) { '::endgroup::' } else { "::group::$Name" }) }
        'AzureDevOps' { Write-MtConsoleLine $(if ($End) { '##[endgroup]' } else { "##[group]$Name" }) }
    }
}

function Write-MtCIAnnotation {
    <#
    .SYNOPSIS
    Writes the first Failed and Error rows as GitHub Actions or Azure Pipelines annotations.

    .DESCRIPTION
    Failed rows are warnings (a finding in the tenant) and Error rows are errors (the test could not run).
    At most -Limit rows are annotated, followed by one line with the number left out.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Tests,
        [Parameter()] [int] $Limit = 20,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    if (-not $Console -or $Console.CI -notin 'GitHubActions', 'AzureDevOps') { return }
    $rows = @($Tests | Where-Object { $_.Result -in 'Failed', 'Error' })
    foreach ($row in ($rows | Select-Object -First $Limit)) {
        $level = if ($row.Result -eq 'Error') { 'error' } else { 'warning' }
        $title = if ($row.PSObject.Properties['Id'] -and $row.Id) { [string]$row.Id } else { [string]$row.Name }
        $detail = if ($row.PSObject.Properties['ReasonDetail'] -and $row.ReasonDetail) { Get-MtFirstLine $row.ReasonDetail } else { $null }
        $name = if ($row.PSObject.Properties['Title'] -and $row.Title) { [string]$row.Title } else { [string]$row.Name }
        $message = "$($row.Result): $name$(if ($detail) { " - $detail" })"
        if ($Console.CI -eq 'GitHubActions') {
            $escape = { param($s) $s.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A') }
            $titleText = (& $escape $title).Replace(':', '%3A').Replace(',', '%2C')
            Write-MtConsoleLine "::$level title=Maester ${titleText}::$(& $escape $message)"
        } else {
            $text = "${title}: $message".Replace('%', '%AZP25').Replace("`r", '%0D').Replace("`n", '%0A').Replace(';', '%3B').Replace(']', '%5D')
            Write-MtConsoleLine "##vso[task.logissue type=$level]$text"
        }
    }
    if ($rows.Count -gt $Limit) {
        Write-MtConsoleLine "Maester: $($rows.Count - $Limit) more failed or errored tests are in the report."
    }
}

function Write-MtRunSummary {
    <#
    .SYNOPSIS
    Writes the end-of-run summary: the count of each result, the duration and the report path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject] $MaesterResults,
        [Parameter()] [string] $ReportPath,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    if (-not $Console) { $Console = Get-MtConsoleMode }
    $duration = $null
    if ($MaesterResults.PSObject.Properties['TotalDuration'] -and $MaesterResults.TotalDuration) {
        try { $duration = Format-MtDuration ([timespan]::Parse([string]$MaesterResults.TotalDuration, [cultureinfo]::InvariantCulture)) } catch { $duration = $null }
    }
    $parts = @(
        [pscustomobject]@{ Result = 'Passed'; Count = $MaesterResults.PassedCount; Label = 'passed' }
        [pscustomobject]@{ Result = 'Failed'; Count = $MaesterResults.FailedCount; Label = 'failed' }
        [pscustomobject]@{ Result = 'Error'; Count = $MaesterResults.ErrorCount; Label = 'errors' }
        [pscustomobject]@{ Result = 'Investigate'; Count = $MaesterResults.InvestigateCount; Label = 'investigate' }
        [pscustomobject]@{ Result = 'Skipped'; Count = $MaesterResults.SkippedCount; Label = 'skipped' }
        [pscustomobject]@{ Result = 'NotRun'; Count = $MaesterResults.NotRunCount; Label = 'not run' }
    )
    $text = foreach ($p in $parts) {
        $style = if ($p.Count -gt 0 -and $p.Result -in 'Passed', 'Failed', 'Error', 'Investigate') { $p.Result } else { 'Dim' }
        if ($Console.Unicode) {
            $symbol = (Format-MtResultLabel -Result $p.Result -Console $Console).Split(' ')[0]
            Format-MtConsoleText "$symbol $($p.Count) $($p.Label)" -Style $style -Console $Console
        } else {
            "$($p.Label.Substring(0, 1).ToUpperInvariant())$($p.Label.Substring(1)): $($p.Count)"
        }
    }
    $separator = if ($Console.Unicode) { '  ' } else { ', ' }
    $total = "$($MaesterResults.TotalCount) tests$(if ($duration) { ", $duration" })"
    Write-MtConsoleLine ''
    Write-MtConsoleLine "  $($text -join $separator)  $(Format-MtConsoleText "($total)" -Style Dim -Console $Console)"
    if ($ReportPath) {
        $shown = $ReportPath
        if ($Console.Hyperlink) {
            $esc = [char]27
            $uri = ([System.Uri]::new([System.IO.Path]::GetFullPath($ReportPath))).AbsoluteUri
            $shown = "$esc]8;;$uri$esc\$ReportPath$esc]8;;$esc\"
        }
        Write-MtConsoleLine "  $(Format-MtConsoleText 'Report:' -Style Bold -Console $Console) $shown"
    }
    Write-MtConsoleLine ''
}

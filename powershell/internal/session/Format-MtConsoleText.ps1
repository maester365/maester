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

function Format-MtCompactNumber {
    <#
    .SYNOPSIS
    Formats a count in a few characters: 950, 1.2K, 48K, 3.4M, 1.1B.

    .DESCRIPTION
    Numbers under a thousand are written in full. Larger ones get one decimal at most and K, M or B.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)] [long] $Number
    )
    $value = [double][math]::Abs($Number)
    $sign = if ($Number -lt 0) { '-' } else { '' }
    $suffixes = '', 'K', 'M', 'B', 'T'
    $index = 0
    # 999,950 is 1M, not 1000K: step up while the rounded value would reach a thousand.
    while ($index -lt $suffixes.Count - 1 -and [math]::Round($value, $(if ($index -eq 0) { 0 } else { 1 })) -ge 1000) {
        $value = $value / 1000
        $index++
    }
    $sign + $value.ToString($(if ($index -eq 0) { '0' } else { '0.#' }), [cultureinfo]::InvariantCulture) + $suffixes[$index]
}

function Get-MtConnectionInfo {
    <#
    .SYNOPSIS
    Lists the services of a run for the console: connected or not, and how many tests are skipped for it.

    .DESCRIPTION
    Reads the tenant context the run already has; it makes no calls. A service that is not connected is listed
    when tests are skipped for it. Opt-in services (Active Directory) are only listed when connected.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowNull()] [pscustomobject] $TenantContext,
        # Rows from Resolve-MtNativePlan.
        [Parameter()] [AllowEmptyCollection()] [object[]] $Plan = @()
    )
    if (-not $TenantContext -or -not $TenantContext.Services) { return }
    $display = @{ ExchangeOnline = 'Exchange Online'; SecurityCompliance = 'Security & Compliance'; SharePointOnline = 'SharePoint Online'; AzureDevOps = 'Azure DevOps'; ActiveDirectory = 'Active Directory' }
    $registry = Get-MtServiceRegistry
    # Skipped tests per service, counted in one pass over the plan.
    $skippedFor = @{}
    foreach ($row in $Plan) {
        if ($row.Disposition -ne 'Skipped') { continue }
        foreach ($service in @($row.Test.Service)) { $skippedFor[[string]$service] = 1 + [int]$skippedFor[[string]$service] }
    }
    foreach ($property in $TenantContext.Services.PSObject.Properties) {
        $name = $property.Name
        $connected = [bool]$property.Value
        $skipped = [int]$skippedFor[$name]
        if (-not $connected -and ($registry.Services[$name].OptIn -or $skipped -eq 0)) { continue }
        $detail = if (-not $connected) { "not connected · $skipped test$(if ($skipped -ne 1) { 's' }) will be skipped" }
        elseif ($name -eq 'Graph') { (@($TenantContext.TenantName, $TenantContext.Account) | Where-Object { $_ }) -join ' · ' }
        else { 'connected' }
        [pscustomobject]@{
            Name      = if ($display.ContainsKey($name)) { $display[$name] } else { $name }
            Connected = $connected
            Detail    = $detail
        }
    }
}

function Format-MtConnectionInfo {
    <#
    .SYNOPSIS
    Formats the connection list: one line per service, or -OneLine for the dashboard header.

    .DESCRIPTION
    -OneLine returns Text (with colour when the console uses it) and Length, its visible length.
    #>
    [CmdletBinding()]
    [OutputType([string], [pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Connection,
        [Parameter()] [switch] $OneLine,
        # With -OneLine: leave out the tenant and the account (the dashboard has them in its Tenant panel).
        [Parameter()] [switch] $NoTenant,
        [Parameter()] [AllowNull()] [pscustomobject] $Console
    )
    $on = if ($Console -and $Console.Unicode) { '●' } else { '*' }
    $off = if ($Console -and $Console.Unicode) { '○' } else { 'o' }
    if ($OneLine) {
        $graph = $Connection | Where-Object { $_.Name -eq 'Graph' -and $_.Connected } | Select-Object -First 1
        $plain = ' '
        $text = ' '
        if ($graph -and $graph.Detail -and -not $NoTenant) {
            $plain += "$($graph.Detail) · "
            $text += "$(Format-MtConsoleText $graph.Detail -Style Bold -Console $Console)$(Format-MtConsoleText ' · ' -Style Dim -Console $Console)"
        }
        foreach ($c in $Connection) {
            $plain += "$(if ($c.Connected) { $on } else { $off }) $($c.Name)  "
            $text += if ($c.Connected) { "$(Format-MtConsoleText $on -Style Passed -Console $Console) $(Format-MtConsoleText $c.Name -Style Dim -Console $Console)  " }
            else { Format-MtConsoleText "$off $($c.Name)  " -Style Dim -Console $Console }
        }
        return [pscustomobject]@{ Text = $text.TrimEnd(); Length = $plain.TrimEnd().Length }
    }
    $width = (@($Connection | ForEach-Object { $_.Name.Length }) + 5 | Measure-Object -Maximum).Maximum + 3
    foreach ($c in $Connection) {
        if ($c.Connected) {
            " $(Format-MtConsoleText $on -Style Passed -Console $Console) $($c.Name.PadRight($width))$(Format-MtConsoleText $c.Detail -Style $(if ($c.Name -eq 'Graph') { 'Bold' } else { 'Dim' }) -Console $Console)"
        } else {
            Format-MtConsoleText " $off $($c.Name.PadRight($width))$($c.Detail)" -Style Dim -Console $Console
        }
    }
}

function Write-MtRunSummary {
    <#
    .SYNOPSIS
    Writes the end-of-run summary: results by product, the count of each result, the duration and the report path.

    .DESCRIPTION
    The table has one row per product (the Product of each test; tests without one are under Other) with
    the tests that ran or were skipped, and the highest severity among the product's failed tests.
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
    Write-MtConsoleLine ''

    # Results by product.
    $severityRank = @{ Critical = 4; High = 3; Medium = 2; Low = 1; Info = 0 }
    $severityStyle = @{ Critical = 'Failed'; High = 'Error'; Medium = 'Error'; Low = 'Dim'; Info = 'Dim' }
    $order = @((Get-MtTestSchema).Products)
    $groups = @($MaesterResults.Tests | Where-Object { $_.Result -ne 'NotRun' } |
            Group-Object { if ($_.PSObject.Properties['Product'] -and $_.Product) { [string]$_.Product } else { 'Other' } } |
            Sort-Object { $i = $order.IndexOf($_.Name); if ($i -lt 0) { 999 } else { $i } }, Name)
    if ($groups.Count -gt 0) {
        $nameWidth = [math]::Max(12, ($groups | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum)
        $cell = { param($value, $width, $style) $value = [int]$value; $text = ([string]$value).PadLeft($width); if ($value -gt 0) { Format-MtConsoleText $text -Style $style -Console $Console } else { Format-MtConsoleText $text -Style Dim -Console $Console } }
        Write-MtConsoleLine (Format-MtConsoleText " $('Product'.PadRight($nameWidth))  Passed  Failed  Errors  Investigate  Skipped   Worst failure" -Style Dim -Console $Console)
        foreach ($g in $groups) {
            $count = @{}
            foreach ($t in $g.Group) { $count[[string]$t.Result]++ }
            $worst = $g.Group | Where-Object { $_.Result -eq 'Failed' -and $_.Severity } | Sort-Object { $severityRank[[string]$_.Severity] } -Descending | Select-Object -First 1
            $worstText = if ($worst) { Format-MtConsoleText ([string]$worst.Severity) -Style $severityStyle[[string]$worst.Severity] -Console $Console } else { '' }
            Write-MtConsoleLine (" $(Format-MtConsoleText $g.Name.PadRight($nameWidth) -Style Bold -Console $Console)" +
                (& $cell $count['Passed'] 8 'Passed') + (& $cell $count['Failed'] 8 'Failed') + (& $cell $count['Error'] 8 'Error') +
                (& $cell $count['Investigate'] 13 'Investigate') + (& $cell $count['Skipped'] 9 'Dim') + "   $worstText").TrimEnd()
        }
        Write-MtConsoleLine (Format-MtConsoleText " $($(if ($Console.Unicode) { '─' } else { '-' }) * ($nameWidth + 62))" -Style Dim -Console $Console)
    }

    # Totals.
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
    Write-MtConsoleLine " $($text -join $separator)  $(Format-MtConsoleText "($total)" -Style Dim -Console $Console)"
    if ($ReportPath) {
        $shown = $ReportPath
        if ($Console.Hyperlink) {
            $esc = [char]27
            $uri = ([System.Uri]::new([System.IO.Path]::GetFullPath($ReportPath))).AbsoluteUri
            $shown = "$esc]8;;$uri$esc\$ReportPath$esc]8;;$esc\"
        }
        Write-MtConsoleLine " $(Format-MtConsoleText 'Report' -Style Bold -Console $Console) $shown"
    }
    Write-MtConsoleLine ''
}

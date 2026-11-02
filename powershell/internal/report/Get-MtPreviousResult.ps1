function Get-MtPreviousResult {
    <#
    .SYNOPSIS
    Returns the result of the previous run on the same tenant, reduced to what a report needs to show changes.

    .DESCRIPTION
    Looks for TestResults-*.json files in -Folder, skipping -Exclude (the file this run writes) and any file that
    is not a Maester result or is for another tenant. Returns ExecutedAt, File (the file name) and Results, a map
    of test ID to result (Passed, Failed, Investigate, Error, Skipped, NotRun), of the newest earlier result, and
    History: the counts of up to -HistoryCount earlier runs, newest first, for the report's trend. Returns nothing
    when there is no earlier result for the tenant.

    Only Id and Result are kept, so the report shows which tests started or stopped failing without carrying a
    second copy of the findings. The comparison is the one Compare-MtTestResult makes. A result file starts with
    its counts, ExecutedAt and TenantId, so History reads only the start of each file; only the newest file is
    read in full.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The output folder of the run.
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $Folder,

        # The tenant of this run. A result for another tenant is skipped; with no tenant, none is.
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $TenantId,

        # Files that are never the previous result, such as the JSON file this run writes.
        [Parameter()] [AllowNull()] [AllowEmptyCollection()] [string[]] $Exclude = @(),

        # How many of the newest files are looked at.
        [Parameter()] [int] $MaxFiles = 15,

        # How many earlier runs History lists.
        [Parameter()] [int] $HistoryCount = 10
    )

    if (-not $Folder -or -not (Test-Path -LiteralPath $Folder -PathType Container)) { return }
    $skip = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in @($Exclude | Where-Object { $_ })) {
        $full = [System.IO.Path]::GetFullPath($path, (Get-Location).Path)
        $null = $skip.Add($full)
    }

    $files = @(Get-ChildItem -LiteralPath $Folder -Filter 'TestResults-*.json' -File -ErrorAction SilentlyContinue |
            Where-Object { -not $skip.Contains($_.FullName) } |
            Sort-Object -Property LastWriteTimeUtc -Descending |
            Select-Object -First $MaxFiles)

    # The start of a result file holds its counts, ExecutedAt and TenantId; the tests come later.
    $headers = foreach ($file in $files) {
        $head = ''
        try {
            $stream = [System.IO.File]::OpenRead($file.FullName)
            try {
                $buffer = [byte[]]::new([math]::Min(8192, $stream.Length))
                $read = $stream.Read($buffer, 0, $buffer.Length)
                $head = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
            } finally { $stream.Dispose() }
        } catch {
            Write-Verbose "Skipping $($file.Name) as a previous result: $($_.Exception.Message)"
            continue
        }
        if ($head -notmatch '"ExecutedAt"\s*:\s*"([^"]+)"') { continue }
        $executedAt = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse($Matches[1], [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$executedAt)) { continue }
        if ($TenantId -and $head -match '"TenantId"\s*:\s*"([^"]*)"' -and $Matches[1] -and $Matches[1] -ne $TenantId) { continue }
        $counts = [ordered]@{}
        foreach ($name in 'Total', 'Passed', 'Failed', 'Investigate', 'Error', 'Skipped', 'NotRun') {
            if ($head -match """$($name)Count""\s*:\s*(\d+)") { $counts[$name] = [int]$Matches[1] }
        }
        [pscustomobject]@{ File = $file; ExecutedAt = $executedAt; Counts = $counts }
    }
    $headers = @($headers | Sort-Object -Property ExecutedAt -Descending)

    # The newest earlier result that reads as a Maester result gives the per-test results.
    $previous = $null
    foreach ($header in $headers) {
        try {
            $result = Get-Content -LiteralPath $header.File.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-Verbose "Skipping $($header.File.Name) as a previous result: $($_.Exception.Message)"
            continue
        }
        if ($result -isnot [pscustomobject] -or -not $result.PSObject.Properties['Tests']) { continue }
        $previous = [pscustomobject]@{ Header = $header; Result = $result }
        break
    }
    if (-not $previous) { return }

    $results = [ordered]@{}
    foreach ($row in @($previous.Result.Tests)) {
        # A 2.x result has no Id on every row: its Name starts with the ID.
        $id = if ($row.PSObject.Properties['Id'] -and $row.Id) { [string]$row.Id } elseif ($row.PSObject.Properties['Name'] -and [string]$row.Name -match '^([^\s:]+):') { $Matches[1] } else { $null }
        if ($id -and -not $results.Contains($id)) { $results[$id] = [string]$row.Result }
    }
    $history = @($headers | Where-Object { $_.Counts.Contains('Total') } | Select-Object -First $HistoryCount | ForEach-Object {
            $entry = [ordered]@{ ExecutedAt = $_.ExecutedAt.ToString('o', [cultureinfo]::InvariantCulture) }
            foreach ($key in $_.Counts.Keys) { $entry[$key] = $_.Counts[$key] }
            [pscustomobject]$entry
        })
    [pscustomobject][ordered]@{
        ExecutedAt = $previous.Header.ExecutedAt.ToString('o', [cultureinfo]::InvariantCulture)
        File       = $previous.Header.File.Name
        Results    = [pscustomobject]$results
        History    = $history
    }
}

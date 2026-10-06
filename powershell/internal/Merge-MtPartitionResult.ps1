function Merge-MtPartitionResult {
    <#
    .SYNOPSIS
    Merges the partial results of one run split across processes or containers (design section 13.1).

    .DESCRIPTION
    Used by Merge-MtMaesterResult -SameRun. Rows are united by ID; a row that ran replaces a NotRun row
    for the same ID. Rows without an ID are kept as they are. Counts, blocks and the run result are
    recomputed, and each partial result's tenant, timing and command are kept under Partitions.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [psobject[]] $Results
    )

    $catalogVersions = @($Results | ForEach-Object { if ($_.PSObject.Properties['CatalogVersion']) { [string]$_.CatalogVersion } else { [string]$_.CurrentVersion } } | Select-Object -Unique)
    if ($catalogVersions.Count -gt 1) {
        throw "The partial results come from different catalog versions ($($catalogVersions -join ', ')). Run every partition with the same Maester version."
    }
    $runIds = @($Results | ForEach-Object { if ($_.PSObject.Properties['RunMetadata'] -and $_.RunMetadata -and $_.RunMetadata.PSObject.Properties['RunId']) { [string]$_.RunMetadata.RunId } } | Where-Object { $_ } | Select-Object -Unique)
    if ($runIds.Count -gt 1) {
        throw "The partial results have different RunMetadata.RunId values ($($runIds -join ', ')). Merge only the partitions of one run."
    }

    $byId = [ordered]@{}
    $noId = [System.Collections.Generic.List[object]]::new()
    foreach ($result in $Results) {
        foreach ($row in @($result.Tests)) {
            if (-not $row.Id) { $noId.Add($row); continue }
            $key = [string]$row.Id
            if (-not $byId.Contains($key)) { $byId[$key] = $row; continue }
            $existing = $byId[$key]
            if ($existing.Result -eq 'NotRun' -and $row.Result -ne 'NotRun') {
                $byId[$key] = $row
            } elseif ($existing.Result -ne 'NotRun' -and $row.Result -ne 'NotRun') {
                Write-Warning "Test $key ran in more than one partition; the first result is kept."
            }
        }
    }
    # A partition that did not select a family reports one NotRun row on the parent ID; drop it when
    # another partition ran the family's instances.
    $ranParents = @($byId.Values | Where-Object { $_.Result -ne 'NotRun' -and $_.PSObject.Properties['ParentId'] -and $_.ParentId } | ForEach-Object { [string]$_.ParentId } | Select-Object -Unique)
    foreach ($parent in $ranParents) {
        if ($byId.Contains($parent) -and $byId[$parent].Result -eq 'NotRun') { $byId.Remove($parent) }
    }
    $rows = @($byId.Values) + @($noId)
    $active = @($rows | Where-Object { $_.Result -eq 'Passed' -or $_.Result -eq 'Failed' } | Sort-Object -Property Name)
    $inactive = @($rows | Where-Object { $_.Result -ne 'Passed' -and $_.Result -ne 'Failed' } | Sort-Object -Property Name)
    $rows = @($active) + @($inactive)
    $index = 0
    foreach ($row in $rows) { $index++; if ($row.PSObject.Properties['Index']) { $row.Index = $index } }

    $counters = 'Failed', 'Passed', 'Error', 'Investigate', 'Skipped', 'NotRun'
    $blocks = foreach ($name in @($rows | ForEach-Object { $_.Block } | Where-Object { $_ } | Select-Object -Unique)) {
        $blockRows = @($rows | Where-Object { $_.Block -eq $name })
        $block = [ordered]@{ Name = $name; Result = if ($blockRows | Where-Object { $_.Result -eq 'Failed' }) { 'Failed' } else { 'Passed' } }
        foreach ($counter in $counters) { $block["$($counter)Count"] = @($blockRows | Where-Object { $_.Result -eq $counter }).Count }
        $block.TotalCount = $blockRows.Count
        $previous = $Results | ForEach-Object { $_.Blocks } | Where-Object { $_ -and $_.Name -eq $name } | Select-Object -First 1
        $block.Tag = if ($previous) { $previous.Tag } else { @() }
        [pscustomobject]$block
    }

    $parseDuration = { param($value) $span = [timespan]::Zero; if ($value -and [timespan]::TryParse([string]$value, [ref]$span)) { $span } else { [timespan]::Zero } }
    $longest = ($Results | ForEach-Object { & $parseDuration $_.TotalDuration } | Sort-Object -Descending | Select-Object -First 1)
    $first = $Results[0]
    $partitions = foreach ($result in $Results) {
        [pscustomobject]@{
            TenantId      = $result.TenantId
            TenantContext = if ($result.PSObject.Properties['TenantContext']) { $result.TenantContext } else { $null }
            ExecutedAt    = $result.ExecutedAt
            TotalDuration = $result.TotalDuration
            Result        = $result.Result
            TotalCount    = $result.TotalCount
            InvokeCommand = $result.InvokeCommand
        }
    }
    $unknownIds = @($Results | ForEach-Object { if ($_.PSObject.Properties['Selection'] -and $_.Selection) { $_.Selection.UnknownIds } } | Where-Object { $_ } | Select-Object -Unique)

    $merged = [ordered]@{}
    foreach ($property in $first.PSObject.Properties) { $merged[$property.Name] = $property.Value }
    $merged.Result = if ($Results | Where-Object { $_.Result -eq 'Failed' }) { 'Failed' } elseif ($rows | Where-Object { $_.Result -eq 'Failed' }) { 'Failed' } else { 'Passed' }
    foreach ($counter in $counters) { $merged["$($counter)Count"] = @($rows | Where-Object { $_.Result -eq $counter }).Count }
    $merged.TotalCount = $rows.Count
    $merged.ExecutedAt = ($Results | ForEach-Object { $_.ExecutedAt } | Sort-Object | Select-Object -First 1)
    if ($longest) { $merged.TotalDuration = $longest.ToString('hh\:mm\:ss\.fff') }
    $merged.Selection = [pscustomobject]@{
        BuiltIn    = if ($first.PSObject.Properties['Selection'] -and $first.Selection) { $first.Selection.BuiltIn } else { 'All' }
        UnknownIds = $unknownIds
        Superseded = @($Results | ForEach-Object { if ($_.PSObject.Properties['Selection'] -and $_.Selection) { $_.Selection.Superseded } } | Where-Object { $_ })
    }
    $merged.Partitions = @($partitions)
    $merged.Tests = $rows
    $merged.Blocks = @($blocks)
    # EndOfJson stays the last property.
    $merged.Remove('EndOfJson')
    $merged.EndOfJson = 'EndOfJson'
    [pscustomobject]$merged
}

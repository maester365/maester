<#
.SYNOPSIS
    Compares two Maester result JSON files for the 2.x to 3.0 parity harness.

.DESCRIPTION
    Reads two TestResults-*.json files written by Invoke-Maester (the shape built by
    powershell/internal/ConvertTo-MtMaesterResult.ps1) and reports every difference in
    the fields the parity harness checks (docs/proposals/maester-3.0-design.md section 14):

    Per row:   Result, Severity, Title, Name, Block, HelpUrl, Tag (as a set, one
               difference per added or removed tag), TestSkipped and SkippedReason
               (from ResultDetail), and Presence (rows missing from either file).
    Run level: Result, FailedCount, PassedCount, ErrorCount, InvestigateCount,
               SkippedCount, NotRunCount, TotalCount.

    Rows are joined by Id, falling back to Name when Id is empty, case-insensitively.
    When a key occurs more than once in either file the rows are paired in file order
    and the key is listed in the summary's DuplicateKeys.

    Each difference is checked against the allow-list (parity-allowlist.psd1 next to
    this script by default), which encodes the intended differences in design section
    5.3. Deny rules win over allow rules: Failed -> Skipped is never allow-listed.
    Run-level differences are allow-listed when every row-level Result and Presence
    difference is allow-listed and the counts reconcile with those row changes.

    This is a build script, not a module command. It is unrelated to the exported
    Compare-MtTestResult command, which compares two runs of the same tenant over time.

.PARAMETER OldPath
    The reference result JSON (for example the 2.x run).

.PARAMETER NewPath
    The result JSON to check (for example the 3.0 run).

.PARAMETER OldResult
    The reference result as an already parsed object.

.PARAMETER NewResult
    The result to check as an already parsed object.

.PARAMETER AllowListPath
    The allow-list data file. Defaults to parity-allowlist.psd1 next to this script.

.PARAMETER NoAllowList
    Ignore the allow-list: every difference is reported as not allow-listed.

.PARAMETER Field
    Restrict the row-level comparison to these fields. Presence and run-level fields are
    always compared.

.PARAMETER FailOnDifference
    After writing the output, exit with code 1 when any difference is not allow-listed.

.PARAMETER AsMarkdown
    Write a Markdown report (a single string) instead of difference objects.

.PARAMETER Summary
    Write the summary object instead of difference objects.

.EXAMPLE
    ./build/parity/Compare-MtTestResult.ps1 -OldPath ./v2/TestResults.json -NewPath ./v3/TestResults.json

    Lists every difference with its allow-list status.

.EXAMPLE
    ./build/parity/Compare-MtTestResult.ps1 -OldPath old.json -NewPath new.json -AsMarkdown -FailOnDifference > parity.md

    Writes a Markdown report and exits with code 1 when a difference is not allow-listed.
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')]
    [string] $OldPath,

    [Parameter(Mandatory, Position = 1, ParameterSetName = 'Path')]
    [string] $NewPath,

    [Parameter(Mandatory, ParameterSetName = 'Object')]
    [psobject] $OldResult,

    [Parameter(Mandatory, ParameterSetName = 'Object')]
    [psobject] $NewResult,

    [string] $AllowListPath = (Join-Path $PSScriptRoot 'parity-allowlist.psd1'),

    [switch] $NoAllowList,

    [ValidateSet('Result', 'Severity', 'Title', 'Name', 'Block', 'HelpUrl', 'Tag', 'TestSkipped', 'SkippedReason')]
    [string[]] $Field = @('Result', 'Severity', 'Title', 'Name', 'Block', 'HelpUrl', 'Tag', 'TestSkipped', 'SkippedReason'),

    [switch] $FailOnDifference,

    [switch] $AsMarkdown,

    [switch] $Summary
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:RunCountFields = [ordered]@{
    FailedCount      = 'Failed'
    PassedCount      = 'Passed'
    ErrorCount       = 'Error'
    InvestigateCount = 'Investigate'
    SkippedCount     = 'Skipped'
    NotRunCount      = 'NotRun'
    TotalCount       = $null
}
$script:RunKey = '(run)'

#region Helpers
function Read-MtResultFile {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Result file not found: $Path"
    }
    $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ($json | ConvertFrom-Json -Depth 100)
}

function Get-MtPropertyValue {
    # Reads a property, or a dotted property path, from an object or hashtable. Returns
    # $null when any segment is missing, so StrictMode does not throw on absent fields.
    param($InputObject, [string] $Path)
    $current = $InputObject
    foreach ($segment in $Path.Split('.')) {
        if ($null -eq $current) { return $null }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($segment)) { return $null }
            $current = $current[$segment]
            continue
        }
        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) { return $null }
        $current = $property.Value
    }
    return $current
}

function ConvertTo-MtComparableString {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return (@($Value | ForEach-Object { ConvertTo-MtComparableString $_ }) -join ', ')
    }
    return [string]$Value
}

function Get-MtRowFieldValue {
    param($Row, [string] $Name)
    switch ($Name) {
        'TestSkipped' { return ConvertTo-MtComparableString (Get-MtPropertyValue $Row 'ResultDetail.TestSkipped') }
        'SkippedReason' { return ConvertTo-MtComparableString (Get-MtPropertyValue $Row 'ResultDetail.SkippedReason') }
        default { return ConvertTo-MtComparableString (Get-MtPropertyValue $Row $Name) }
    }
}

function Get-MtRowTagSet {
    param($Row)
    # Case-insensitive set; keeps first-seen order for stable output. Empty-string tags
    # occur in real 2.x results and are kept as members.
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ordered = [System.Collections.Generic.List[string]]::new()
    foreach ($tag in @(Get-MtPropertyValue $Row 'Tag')) {
        if ($null -eq $tag) { continue }
        if ($set.Add([string]$tag)) { $ordered.Add([string]$tag) }
    }
    return [pscustomobject]@{ Set = $set; List = $ordered }
}

function Get-MtRowKey {
    param($Row)
    $id = ConvertTo-MtComparableString (Get-MtPropertyValue $Row 'Id')
    if (-not [string]::IsNullOrWhiteSpace($id)) { return $id.Trim() }
    return (ConvertTo-MtComparableString (Get-MtPropertyValue $Row 'Name')).Trim()
}

function Group-MtRowsByKey {
    param([object[]] $Rows)
    $map = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $Rows) {
        if ($null -eq $row) { continue }
        $key = Get-MtRowKey $row
        if (-not $map.Contains($key)) { $map[$key] = [System.Collections.Generic.List[object]]::new() }
        $map[$key].Add($row)
    }
    return $map
}

function Test-MtPattern {
    param([string] $Value, $Pattern)
    if ($null -eq $Pattern) { return $true }
    return [regex]::IsMatch($Value, [string]$Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Test-MtConditionSet {
    # Every path -> pattern pair must match. A condition on an absent object never matches.
    param($Target, $Conditions)
    if ($null -eq $Conditions -or $Conditions.Count -eq 0) { return $true }
    if ($null -eq $Target) { return $false }
    foreach ($path in $Conditions.Keys) {
        $value = ConvertTo-MtComparableString (Get-MtPropertyValue $Target $path)
        if (-not (Test-MtPattern $value $Conditions[$path])) { return $false }
    }
    return $true
}

function Test-MtRuleMatch {
    param($Rule, $Difference, $OldRow, $NewRow, $NewRun)
    $ruleField = [string]$Rule['Field']
    if ($Rule['FieldIsPattern']) {
        if (-not (Test-MtPattern $Difference.Field $ruleField)) { return $false }
    } elseif ($Difference.Field -ne $ruleField) {
        return $false
    }
    if ($Rule.ContainsKey('IdList')) {
        $listed = @($Rule['IdList'] | Where-Object { $_ -ieq $Difference.Id })
        if ($listed.Count -eq 0) { return $false }
    }
    if (-not (Test-MtPattern $Difference.Id $Rule['Id'])) { return $false }
    if (-not (Test-MtPattern (ConvertTo-MtComparableString $Difference.Old) $Rule['Old'])) { return $false }
    if (-not (Test-MtPattern (ConvertTo-MtComparableString $Difference.New) $Rule['New'])) { return $false }
    if (-not (Test-MtConditionSet $NewRow $Rule['NewRow'])) { return $false }
    if (-not (Test-MtConditionSet $OldRow $Rule['OldRow'])) { return $false }
    if (-not (Test-MtConditionSet $NewRun $Rule['NewRun'])) { return $false }
    return $true
}

function Build-MtDifference {
    param([string] $Id, [string] $Name, $Old, $New, [int] $Occurrence = 1)
    [pscustomobject]@{
        PSTypeName    = 'MaesterParity.Difference'
        Id            = $Id
        Field         = $Name
        Old           = $Old
        New           = $New
        AllowListed   = $false
        AllowListRule = $null
        DenyRule      = $null
        Occurrence    = $Occurrence
    }
}

function Resolve-MtAllowListStatus {
    param($Difference, $OldRow, $NewRow, $NewRun, $AllowList)
    if ($null -eq $AllowList) { return }
    foreach ($rule in @($AllowList['Deny'])) {
        if ($null -eq $rule) { continue }
        if (Test-MtRuleMatch -Rule $rule -Difference $Difference -OldRow $OldRow -NewRow $NewRow -NewRun $NewRun) {
            $Difference.DenyRule = $rule['Name']
            return
        }
    }
    foreach ($rule in @($AllowList['Rules'])) {
        if ($null -eq $rule) { continue }
        if (Test-MtRuleMatch -Rule $rule -Difference $Difference -OldRow $OldRow -NewRow $NewRow -NewRun $NewRun) {
            $Difference.AllowListed = $true
            $Difference.AllowListRule = $rule['Name']
            return
        }
    }
}

function Format-MtMarkdownCell {
    param($Value, [int] $MaxLength = 160)
    $text = ConvertTo-MtComparableString $Value
    if ($text -eq '') { return '_(empty)_' }
    $text = ($text -replace '\r?\n', ' ') -replace '\|', '\|'
    if ($text.Length -gt $MaxLength) { $text = $text.Substring(0, $MaxLength) + '...' }
    return $text
}
#endregion Helpers

#region Load
if ($PSCmdlet.ParameterSetName -eq 'Path') {
    $OldResult = Read-MtResultFile $OldPath
    $NewResult = Read-MtResultFile $NewPath
    $oldLabel = $OldPath
    $newLabel = $NewPath
} else {
    $oldLabel = '(object)'
    $newLabel = '(object)'
}

foreach ($pair in @(@{ Label = 'old'; Value = $OldResult }, @{ Label = 'new'; Value = $NewResult })) {
    if ($null -eq $pair.Value.PSObject.Properties['Tests']) {
        if ($null -ne $pair.Value.PSObject.Properties['Tenants']) {
            throw "The $($pair.Label) result is a merged multi-tenant result. Compare one tenant's result at a time."
        }
        throw "The $($pair.Label) result has no Tests array; it is not a Maester result file."
    }
}

$allowList = $null
if (-not $NoAllowList) {
    if (-not (Test-Path -LiteralPath $AllowListPath -PathType Leaf)) {
        throw "Allow-list not found: $AllowListPath"
    }
    $allowList = Import-PowerShellDataFile -LiteralPath $AllowListPath
}
#endregion Load

#region Compare rows
$oldRows = @($OldResult.Tests)
$newRows = @($NewResult.Tests)
$oldMap = Group-MtRowsByKey $oldRows
$newMap = Group-MtRowsByKey $newRows

$allKeys = [System.Collections.Generic.List[string]]::new()
foreach ($key in $oldMap.Keys) { $allKeys.Add($key) }
foreach ($key in $newMap.Keys) { if (-not $oldMap.Contains($key)) { $allKeys.Add($key) } }

$differences = [System.Collections.Generic.List[object]]::new()
$duplicateKeys = [System.Collections.Generic.List[object]]::new()
$matchedRows = 0
$missingRows = 0
$extraRows = 0
$compareTags = $Field -contains 'Tag'
$emptyList = [System.Collections.Generic.List[object]]::new()
$scalarFields = @($Field | Where-Object { $_ -ne 'Tag' })

foreach ($key in $allKeys) {
    # Assign directly: an empty collection returned from an if-expression unrolls to $null.
    $oldList = $emptyList
    $newList = $emptyList
    if ($oldMap.Contains($key)) { $oldList = $oldMap[$key] }
    if ($newMap.Contains($key)) { $newList = $newMap[$key] }
    if ($oldList.Count -gt 1 -or $newList.Count -gt 1) {
        $duplicateKeys.Add([pscustomobject]@{ Key = $key; OldCount = $oldList.Count; NewCount = $newList.Count })
    }

    $pairCount = [Math]::Max($oldList.Count, $newList.Count)
    for ($i = 0; $i -lt $pairCount; $i++) {
        $oldRow = if ($i -lt $oldList.Count) { $oldList[$i] } else { $null }
        $newRow = if ($i -lt $newList.Count) { $newList[$i] } else { $null }
        $rowDiffs = [System.Collections.Generic.List[object]]::new()

        if ($null -eq $oldRow -or $null -eq $newRow) {
            if ($null -eq $oldRow) { $extraRows++ } else { $missingRows++ }
            $rowDiffs.Add((Build-MtDifference -Id $key -Name 'Presence' `
                        -Old (Get-MtRowFieldValue $oldRow 'Result') -New (Get-MtRowFieldValue $newRow 'Result') -Occurrence ($i + 1)))
        } else {
            $matchedRows++
            foreach ($name in $scalarFields) {
                $oldValue = Get-MtRowFieldValue $oldRow $name
                $newValue = Get-MtRowFieldValue $newRow $name
                if ($oldValue -cne $newValue) {
                    $rowDiffs.Add((Build-MtDifference -Id $key -Name $name -Old $oldValue -New $newValue -Occurrence ($i + 1)))
                }
            }
            if ($compareTags) {
                $oldTags = Get-MtRowTagSet $oldRow
                $newTags = Get-MtRowTagSet $newRow
                foreach ($tag in $oldTags.List) {
                    if (-not $newTags.Set.Contains($tag)) {
                        $rowDiffs.Add((Build-MtDifference -Id $key -Name 'Tag' -Old $tag -New '' -Occurrence ($i + 1)))
                    }
                }
                foreach ($tag in $newTags.List) {
                    if (-not $oldTags.Set.Contains($tag)) {
                        $rowDiffs.Add((Build-MtDifference -Id $key -Name 'Tag' -Old '' -New $tag -Occurrence ($i + 1)))
                    }
                }
            }
        }

        foreach ($difference in $rowDiffs) {
            Resolve-MtAllowListStatus -Difference $difference -OldRow $oldRow -NewRow $newRow -NewRun $NewResult -AllowList $allowList
            $differences.Add($difference)
        }
    }
}
#endregion Compare rows

#region Compare run level
$rowResultDiffs = @($differences | Where-Object { $_.Field -in 'Result', 'Presence' })
$rowsExplained = -not ($rowResultDiffs | Where-Object { -not $_.AllowListed })

# Expected new counts if only the allow-listed row changes happened.
$expected = @{}
foreach ($countField in $script:RunCountFields.Keys) {
    $value = Get-MtPropertyValue $OldResult $countField
    $expected[$countField] = if ($null -eq $value) { $null } else { [int]$value }
}
foreach ($difference in $rowResultDiffs) {
    foreach ($countField in @($script:RunCountFields.Keys)) {
        $bucket = $script:RunCountFields[$countField]
        if ($null -eq $bucket -or $null -eq $expected[$countField]) { continue }
        if ($difference.Old -eq $bucket) { $expected[$countField]-- }
        if ($difference.New -eq $bucket) { $expected[$countField]++ }
    }
    if ($difference.Field -eq 'Presence' -and $null -ne $expected['TotalCount']) {
        if ([string]::IsNullOrEmpty($difference.Old)) { $expected['TotalCount']++ }
        if ([string]::IsNullOrEmpty($difference.New)) { $expected['TotalCount']-- }
    }
}

# Design 5.3 item 7: the run is Failed if any row is Failed or the engine raised an Error
# row without running a test. A run-level Result change is derived only when it matches.
$engineReasonCodes = 'InvalidMetadata', 'InvalidConfiguration', 'InvalidInstanceId', 'DuplicateId', 'LoadFailed',
'InstanceSourceFailed', 'RequiresNewerMaester', 'ForeignModuleLoaded', 'PesterNotAvailable'
$runFailed = $newRows | Where-Object {
    (Get-MtRowFieldValue $_ 'Result') -eq 'Failed' -or (Get-MtRowFieldValue $_ 'ReasonCode') -in $engineReasonCodes
}
$expectedRunResult = if ($runFailed) { 'Failed' } else { 'Passed' }

$runFields = @('Result') + @($script:RunCountFields.Keys)
foreach ($runField in $runFields) {
    $oldValue = ConvertTo-MtComparableString (Get-MtPropertyValue $OldResult $runField)
    $newValue = ConvertTo-MtComparableString (Get-MtPropertyValue $NewResult $runField)
    if ($oldValue -ceq $newValue) { continue }
    $difference = Build-MtDifference -Id $script:RunKey -Name $runField -Old $oldValue -New $newValue
    Resolve-MtAllowListStatus -Difference $difference -OldRow $OldResult -NewRow $NewResult -NewRun $NewResult -AllowList $allowList
    if (-not $difference.AllowListed -and -not $difference.DenyRule -and $null -ne $allowList -and $rowsExplained) {
        $reconciles = if ($runField -eq 'Result') { $rowResultDiffs.Count -gt 0 -and $newValue -eq $expectedRunResult } else { [string]$expected[$runField] -eq $newValue }
        if ($reconciles) {
            $difference.AllowListed = $true
            $difference.AllowListRule = 'DerivedFromAllowListedRows'
        }
    }
    $differences.Add($difference)
}
#endregion Compare run level

#region Output
$notAllowListed = @($differences | Where-Object { -not $_.AllowListed })
$byField = [ordered]@{}
foreach ($group in ($notAllowListed | Group-Object Field | Sort-Object Name)) { $byField[$group.Name] = $group.Count }
$byRule = [ordered]@{}
foreach ($group in (@($differences | Where-Object AllowListed) | Group-Object AllowListRule | Sort-Object Name)) { $byRule[$group.Name] = $group.Count }

$summaryObject = [pscustomobject]@{
    PSTypeName          = 'MaesterParity.Summary'
    OldPath             = $oldLabel
    NewPath             = $newLabel
    OldRowCount         = $oldRows.Count
    NewRowCount         = $newRows.Count
    MatchedRows         = $matchedRows
    MissingRows         = $missingRows
    ExtraRows           = $extraRows
    DifferenceCount     = $differences.Count
    AllowListedCount    = $differences.Count - $notAllowListed.Count
    NotAllowListedCount = $notAllowListed.Count
    NotAllowListedBy    = $byField
    AllowListedByRule   = $byRule
    DuplicateKeys       = @($duplicateKeys)
    Passed              = ($notAllowListed.Count -eq 0)
}

$summaryText = "Parity: $($summaryObject.MatchedRows) rows matched, $missingRows missing, $extraRows extra; " +
"$($differences.Count) differences, $($summaryObject.AllowListedCount) allow-listed, $($notAllowListed.Count) not allow-listed."
Write-Information -MessageData $summaryText -Tags 'MaesterParity'
foreach ($duplicate in $duplicateKeys) {
    Write-Verbose "Duplicate key '$($duplicate.Key)': $($duplicate.OldCount) old row(s), $($duplicate.NewCount) new row(s); paired in order."
}

if ($AsMarkdown) {
    $md = [System.Text.StringBuilder]::new()
    $null = $md.AppendLine('# Maester parity report').AppendLine()
    $verdict = if ($summaryObject.Passed) { 'PASS: no difference outside the allow-list.' } else { "FAIL: $($notAllowListed.Count) difference(s) outside the allow-list." }
    $null = $md.AppendLine("**$verdict**").AppendLine()
    $null = $md.AppendLine('| | Count |').AppendLine('| --- | ---: |')
    $null = $md.AppendLine("| Old rows (``$(Format-MtMarkdownCell $oldLabel)``) | $($oldRows.Count) |")
    $null = $md.AppendLine("| New rows (``$(Format-MtMarkdownCell $newLabel)``) | $($newRows.Count) |")
    $null = $md.AppendLine("| Matched rows | $matchedRows |")
    $null = $md.AppendLine("| Missing from new | $missingRows |")
    $null = $md.AppendLine("| Extra in new | $extraRows |")
    $null = $md.AppendLine("| Differences | $($differences.Count) |")
    $null = $md.AppendLine("| Allow-listed | $($summaryObject.AllowListedCount) |")
    $null = $md.AppendLine("| Not allow-listed | $($notAllowListed.Count) |").AppendLine()

    if ($notAllowListed.Count -gt 0) {
        $null = $md.AppendLine('## Differences outside the allow-list').AppendLine()
        $null = $md.AppendLine('| Id | Field | Old | New | Note |').AppendLine('| --- | --- | --- | --- | --- |')
        foreach ($difference in $notAllowListed) {
            $note = if ($difference.DenyRule) { "denied by $($difference.DenyRule)" } elseif ($difference.Occurrence -gt 1) { "occurrence $($difference.Occurrence)" } else { '' }
            $null = $md.AppendLine("| $(Format-MtMarkdownCell $difference.Id) | $($difference.Field) | $(Format-MtMarkdownCell $difference.Old) | $(Format-MtMarkdownCell $difference.New) | $note |")
        }
        $null = $md.AppendLine()
    }

    $allowed = @($differences | Where-Object AllowListed)
    if ($allowed.Count -gt 0) {
        $null = $md.AppendLine('## Allow-listed differences').AppendLine()
        $null = $md.AppendLine('| Rule | Count |').AppendLine('| --- | ---: |')
        foreach ($rule in $byRule.Keys) { $null = $md.AppendLine("| $rule | $($byRule[$rule]) |") }
        $null = $md.AppendLine()
        $null = $md.AppendLine('<details><summary>All allow-listed differences</summary>').AppendLine()
        $null = $md.AppendLine('| Id | Field | Old | New | Rule |').AppendLine('| --- | --- | --- | --- | --- |')
        foreach ($difference in $allowed) {
            $null = $md.AppendLine("| $(Format-MtMarkdownCell $difference.Id) | $($difference.Field) | $(Format-MtMarkdownCell $difference.Old) | $(Format-MtMarkdownCell $difference.New) | $($difference.AllowListRule) |")
        }
        $null = $md.AppendLine().AppendLine('</details>').AppendLine()
    }

    if ($duplicateKeys.Count -gt 0) {
        $null = $md.AppendLine('## Duplicate keys').AppendLine()
        $null = $md.AppendLine('Rows sharing a key are paired in file order.').AppendLine()
        $null = $md.AppendLine('| Key | Old rows | New rows |').AppendLine('| --- | ---: | ---: |')
        foreach ($duplicate in $duplicateKeys) {
            $null = $md.AppendLine("| $(Format-MtMarkdownCell $duplicate.Key) | $($duplicate.OldCount) | $($duplicate.NewCount) |")
        }
        $null = $md.AppendLine()
    }
    $md.ToString()
} elseif ($Summary) {
    $summaryObject
} else {
    $differences
}

if ($FailOnDifference -and $notAllowListed.Count -gt 0) {
    $host.UI.WriteErrorLine("Parity check failed: $($notAllowListed.Count) difference(s) outside the allow-list.")
    exit 1
} elseif ($FailOnDifference) {
    exit 0
}
#endregion Output

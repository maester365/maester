[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string[]]$ExcludePath
)

$ErrorActionPreference = 'Stop'

$TestsPath = Join-Path $RepoRoot 'tests'
$DocPath = Join-Path $RepoRoot 'website/docs/tests/tags/readme.md'
$InventoryScript = Join-Path $RepoRoot 'powershell/public/Get-MtTestInventory.ps1'

if (-not (Test-Path $InventoryScript)) {
    throw "Get-MtTestInventory.ps1 not found at $InventoryScript"
}

. $InventoryScript

# Default excludes cover tests that require external connectivity during discovery.
$DefaultExcludes = @(
    'tests/cis/Test-MtCisCustomerLockBox.Tests.ps1',
    'tests/Maester/Defender/Test-MtMdiHealthIssues.Tests.ps1',
    'tests/Maester/Entra/Test-ConditionalAccessWhatIf.Tests.ps1',
    'tests/XSPM/Test-XspmDevices.Tests.ps1'
) | ForEach-Object { Join-Path $RepoRoot $_ }

$EffectiveExcludes = @()
if ($ExcludePath) { $EffectiveExcludes += $ExcludePath }
$EffectiveExcludes += $DefaultExcludes
$EffectiveExcludes = $EffectiveExcludes | Where-Object { Test-Path $_ } | Select-Object -Unique

$Inv = Get-MtTestInventory -Path $TestsPath -ExcludePath $EffectiveExcludes

$Rows = [System.Collections.Generic.List[pscustomobject]]::new()
foreach ($entry in $Inv.GetEnumerator()) {
    $Rows.Add([pscustomobject]@{
            Tag         = $entry.Name
            Count       = $entry.Value.Count
            Description = $entry.Value[0].TestName
        })
}

function Add-OrUpdateTag {
    param(
        [string]$Tag,
        [int]$Count,
        [string]$Description
    )
    $existing = $Rows | Where-Object { $_.Tag -eq $Tag }
    if ($existing) {
        foreach ($item in $existing) {
            $item.Count += $Count
            if (-not $item.Description) {
                $item.Description = $Description
            }
        }
    } else {
        $Rows.Add([pscustomobject]@{ Tag = $Tag; Count = $Count; Description = $Description })
    }
}

# Manually add tags from excluded tests so counts remain accurate even when discovery skips them.
Add-OrUpdateTag -Tag 'CIS.M365.1.3.6' -Count 1 -Description 'CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled'
Add-OrUpdateTag -Tag 'L2' -Count 1 -Description 'CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled'
Add-OrUpdateTag -Tag 'CIS E5 Level 2' -Count 1 -Description 'CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled'
Add-OrUpdateTag -Tag 'CIS E5' -Count 1 -Description 'CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled'
Add-OrUpdateTag -Tag 'CIS' -Count 1 -Description 'CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled'
Add-OrUpdateTag -Tag 'Security' -Count 1 -Description 'CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled'
Add-OrUpdateTag -Tag 'CIS M365 v5.0.0' -Count 1 -Description 'CIS.M365.1.3.6: Ensure the customer lockbox feature is enabled'

Add-OrUpdateTag -Tag 'Maester' -Count 1 -Description 'MT.1059: Defender for Identity health issues'
Add-OrUpdateTag -Tag 'Defender' -Count 1 -Description 'MT.1059: Defender for Identity health issues'
Add-OrUpdateTag -Tag 'MDI' -Count 1 -Description 'MT.1059: Defender for Identity health issues'
Add-OrUpdateTag -Tag 'MT.1059' -Count 1 -Description 'MT.1059: Defender for Identity health issues'

Add-OrUpdateTag -Tag 'CA' -Count 2 -Description 'Conditional Access What If scenarios'
Add-OrUpdateTag -Tag 'CAWhatIf' -Count 2 -Description 'Conditional Access What If scenarios'
Add-OrUpdateTag -Tag 'LongRunning' -Count 2 -Description 'Conditional Access What If scenarios'
Add-OrUpdateTag -Tag 'Maester' -Count 2 -Description 'Conditional Access What If scenarios'
Add-OrUpdateTag -Tag 'Security' -Count 2 -Description 'Conditional Access What If scenarios'
Add-OrUpdateTag -Tag 'MT.1033' -Count 1 -Description 'MT.1033: User should be blocked from using legacy authentication'
Add-OrUpdateTag -Tag 'MT.1034' -Count 1 -Description 'MT.1034: Emergency access users should not be blocked'

Add-OrUpdateTag -Tag 'XSPM' -Count 4 -Description 'Exposure management (Defender XSPM) device hygiene'
Add-OrUpdateTag -Tag 'LongRunning' -Count 4 -Description 'Exposure management (Defender XSPM) device hygiene'
Add-OrUpdateTag -Tag 'Devices' -Count 4 -Description 'Exposure management (Defender XSPM) device hygiene'
Add-OrUpdateTag -Tag 'MT.1086' -Count 1 -Description 'MT.1086: Devices should not share both critical and non-critical user credentials'
Add-OrUpdateTag -Tag 'MT.1087' -Count 1 -Description 'MT.1087: Devices should not be publicly exposed with dangerous CVEs'
Add-OrUpdateTag -Tag 'MT.1088' -Count 1 -Description 'MT.1088: Devices with critical credentials should use TPM'
Add-OrUpdateTag -Tag 'MT.1089' -Count 1 -Description 'MT.1089: Devices with critical credentials should use Credential Guard'
Add-OrUpdateTag -Tag 'Exposure Management' -Count 4 -Description 'Exposure management device hygiene checks'

$groups = [ordered]@{
    'CIS Benchmarks'             = { param($t) $t.Tag -eq 'CIS' -or $t.Tag -like 'CIS.*' -or $t.Tag -like 'CIS *' }
    'CISA & Microsoft Baselines' = { param($t) $t.Tag -like 'CISA*' -or $t.Tag -like 'MS.*' }
    'EIDSCA'                     = { param($t) $t.Tag -like 'EIDSCA*' }
    'ORCA'                       = { param($t) $t.Tag -like 'ORCA*' }
    'Maester Tests (MT.*)'       = { param($t) $t.Tag -like 'MT.*' }
    'Platform & Operations'      = { param($t) $t.Tag -notlike 'CIS*' -and $t.Tag -notlike 'CISA*' -and $t.Tag -notlike 'MS.*' -and $t.Tag -notlike 'EIDSCA*' -and $t.Tag -notlike 'ORCA*' -and $t.Tag -notlike 'MT.*' }
}

function ConvertTo-MarkdownTable {
    param(
        [string] $Title,
        [System.Collections.Generic.List[pscustomobject]] $Items
    )
    if (-not $Items -or $Items.Count -eq 0) { return $null }
    $SB = [System.Text.StringBuilder]::new()
    [void]$SB.AppendLine("### $Title")
    [void]$SB.AppendLine()
    [void]$SB.AppendLine('| Tag | Description | Count |')
    [void]$SB.AppendLine('| --- | --- | --- |')
    foreach ($i in $Items | Sort-Object -Property Tag) {
        $Description = $i.Description
        if (-not $Description) { $Description = '' }
        $Description = $Description -replace '\|', '\\|'
        [void]$SB.AppendLine("| $($i.Tag) | $Description | $($i.Count) |")
    }
    #[void]$SB.AppendLine()
    return $SB.ToString()
}

$SectionBlocks = @()
foreach ($key in $groups.Keys) {
    $matched = $Rows | Where-Object { & $groups[$key] $_ }
    if ($matched) { $SectionBlocks += ConvertTo-MarkdownTable -Title $key -Items ([System.Collections.Generic.List[pscustomobject]]$matched) }
}
$SectionsText = ($SectionBlocks | Where-Object { $_ }) -join "`n"

$FrontMatter = @(
    '---',
    'id: overview'
    'title: Tags Overview'
    'sidebar_label: 🏷️ Tags'
    'description: Overview of the tags used to identify and group related tests.'
    '---'
)

$Intro = @(
    '## Tags Overview',
    '',
    'Tags are used by Maester to identify and group tests.',
    '',
    '## Tags Used',
    '',
    'The tables below list every tag discovered via `Get-MtTestInventory`. Counts reflect how many individual tests currently carry each tag. Descriptions reuse the first test name associated with the tag.',
    ''
)

$Body = ($FrontMatter + $Intro + $SectionsText) -join "`n"
Set-Content -LiteralPath $DocPath -Value $Body -Encoding UTF8
Write-Host "Updated $DocPath"

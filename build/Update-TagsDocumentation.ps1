[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$TagsDocPath = (Join-Path -Path ((Resolve-Path (Join-Path $PSScriptRoot '..')).Path) -ChildPath 'website/docs/tests/tags/readme.md'),
    [string[]]$ExcludePath
)

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

# Combine user-specified excludes with defaults. Ensure that paths exist and are not duplicated.
$EffectiveExcludes = @()
if ($ExcludePath) { $EffectiveExcludes += $ExcludePath }
$EffectiveExcludes += $DefaultExcludes
$EffectiveExcludes = $EffectiveExcludes | Where-Object { Test-Path $_ } | Select-Object -Unique
# Get test inventory, excluding specified paths.
#$Inventory = Get-MtTestInventory -Path $TestsPath -ExcludePath $EffectiveExcludes

# Get test and tag inventory
$Inventory = Get-MtTestInventory -Path $TestsPath

# Create an inventory of tags grouped by describe block, with a list of strings in each value.
$DescribeInventory = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string[]]]]::new()

# Get all unique describe blocks
$DescribeBlocks = $Inventory.Values.Describe | Sort-Object -Unique

# Get all tags used per describe block
foreach ($Block in $DescribeBlocks) {
    $BlockTags = $Inventory.Values | Where-Object { $_.Describe -eq $Block } | Select-Object -ExpandProperty Tags -ErrorAction SilentlyContinue | Sort-Object -Unique
    $DescribeInventory[$Block] = $BlockTags
}

$Rows = [System.Collections.Generic.List[pscustomobject]]::new()
foreach ($entry in $Inventory.GetEnumerator()) {
    $Rows.Add([pscustomobject]@{
            Tag   = $entry.Name
            Count = $entry.Value.Count
        })
}

function Add-OrUpdateTag {
    param(
        [string]$Tag,
        [int]$Count
    )
    $existing = $Rows | Where-Object { $_.Tag -eq $Tag }
    if ($existing) {
        foreach ($item in $existing) {
            $item.Count += $Count
        }
    } else {
        $Rows.Add([pscustomobject]@{
                Tag   = $Tag
                Count = $Count
            })
    }
} # end function Add-OrUpdateTag

# Manually add tags from excluded tests so counts remain accurate even when discovery skips them.
Add-OrUpdateTag -Tag 'MT.1059' -Count 1
Add-OrUpdateTag -Tag 'MDI' -Count 1

$Groups = [ordered]@{
    'CIS'     = { param($t) $t.Tag -like 'CIS*' }
    'CISA'    = { param($t) $t.Tag -like 'CISA*' -or $t.Tag -like 'MS.*' }
    'ORCA'    = { param($t) $t.Tag -like 'ORCA*' }
    'Maester' = { param($t) $t.Tag -like 'MT.*' -or $t.Tag -like 'Maester*' }
    'EIDSCA'  = { param($t) $t.Tag -like 'EIDSCA*' }
}

function ConvertTo-MarkdownTable {
    param(
        [string] $Title,
        [System.Collections.Generic.List[pscustomobject]] $Items
    )
    if (-not $Items -or $Items.Count -eq 0) { return $null }

    # Split items into multiple use (count > 1) and single use (count = 1)
    $MultipleUse = $Items | Where-Object { $_.Count -gt 1 } | Sort-Object -Property Tag
    $SingleUse = $Items | Where-Object { $_.Count -eq 1 } | Sort-Object -Property Tag

    $SB = [System.Text.StringBuilder]::new()
    [void]$SB.AppendLine("### $Title")
    [void]$SB.AppendLine()

    # Only create table if there are tags used more than once
    if ($MultipleUse) {
        [void]$SB.AppendLine('| Tag | Count |')
        [void]$SB.AppendLine('| --- | --- |')
        foreach ($i in $MultipleUse) {
            [void]$SB.AppendLine("| $($i.Tag) | $($i.Count) |")
        }
        [void]$SB.AppendLine()
    }

    # Add single-use tags as comma-separated list
    if ($SingleUse) {
        $singleTagList = ($SingleUse | ForEach-Object { $_.Tag }) -join ', '
        [void]$SB.AppendLine("**Individual tags**: $singleTagList")
        [void]$SB.AppendLine()
    }

    return $SB.ToString()
}

$SectionBlocks = @()
foreach ($Key in $Groups.Keys) {
    $matched = $Rows | Where-Object { & $Groups[$Key] $_ }
    if ($matched) { $SectionBlocks += ConvertTo-MarkdownTable -Title $Key -Items ([System.Collections.Generic.List[pscustomobject]]$matched) }
}
$SectionsText = ($SectionBlocks | Where-Object { $_ }) -join "`n"

$FrontMatter = @"
---
id: overview
title: Tags Overview
sidebar_label: 🏷️ Tags
description: Overview of the tags used to identify and group related tests.
---

"@

$Intro = @"
## Tags Overview

Tags are used by Maester to identify and group related tests. They can also be used to select specific tests to run or exclude during test execution. This makes them very useful, but they can also get in the way if too many tags are created. Our goal is to minimize the "signal to noise" ratio when it comes to tags by focusing on a few key areas:

1. **Test Suites**: We use standardized tag categories for test suites that align with well-known benchmarks and baselines. This helps users quickly identify tests that align with these widely recognized standards or with Maester's own suite of tests:
  - CIS Benchmarks: Tags prefixed with `CIS` (e.g., `CIS.M365.1.1`, `CIS.Azure.3.2`)
  - CISA & Microsoft Baseline: Tags prefixed with `CISA` or `MS` (e.g., `CISA.M365.Baseline`, `MS.Azure.Baseline`)
  - EIDSCA: Tags prefixed with `EIDSCA` (e.g., `EIDSCA.EntraID.2.1`)
  - ORCA: Tags prefixed with `ORCA` (e.g., `ORCA.Exchange.1.1`)
  - Maester: Tags prefixed with `Maester` or `MT` (e.g., `MT.1001`, `MT.1024`)
2. **Product Areas**: Tags related to specific products and services that are being tested:
  - Azure
  - Defender XDR
  - Entra ID
  - Exchange
  - Microsoft 365
  - SharePoint
  - Teams
3. **Practices or Capabilities**: Tags that denote specific security practices or capabilities within the security domain, such as:
  - Authentication (May include related topics such as MFA, SSPR, etc.)
  - Conditional Access (CA)
  - Data Loss Prevention (DLP)
  - Extended Security Posture Management (XSPM)
  - Hybrid Identity
  - Privileged Access Management (PAM)
  - Privileged Identity Management (PIM)

### Recommendations for Tag Usage

Less is more! When creating or assigning tags to tests, consider the following best practices:

1. Assign one **Test Suite** tag per test to ensure clarity on which benchmark or baseline the test aligns with. This tag will usually go in the `Describe` block of a Pester test file.
2. Assign a **Product Area** tag to indicate which products or services the test is most relevant to. Limit these to 1-3 tags per test to avoid over-tagging.
3. Use **Practice or Capability** tags sparingly and only when they add significant value in categorizing the test. Avoid creating overly specific tags that may only apply to a single test.

## Tags Used

The tables below list every tag discovered via `Get-MtTestInventory`.

"@

$Body = ($FrontMatter + $Intro + $SectionsText) -join "`n"
Set-Content -LiteralPath $DocPath -Value $Body -Encoding UTF8
Write-Host "Updated $DocPath"

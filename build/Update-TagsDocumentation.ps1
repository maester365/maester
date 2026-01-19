# Update-TagsDocumentation.ps1

<#
.SYNOPSIS
    Updates the tags documentation file with an inventory of tags used in Maester tests.

.DESCRIPTION
    This script scans Maester's tests directory for tags used in Pester tests and generates a
    markdown documentation file. The document lists all tags along with their usage counts, grouped by categories.

.PARAMETER RepoRoot
    The path to the root of the repository. Defaults to the parent directory of the script location (i.e., the repository root).

.PARAMETER TestsPath
    The path to the Maester tests directory. Defaults to 'tests' within the repository root.

.PARAMETER TagsDocPath
    The path to the tags documentation file to update. Defaults to 'website/docs/tests/tags/readme.md' within the repository root.

.EXAMPLE
    .\Update-TagsDocumentation.ps1

    Updates the tags documentation file using default paths for the repository root, tests directory, and tags documentation file.

.EXAMPLE
    .\Update-TagsDocumentation.ps1 -RepoRoot 'C:\Maester' -TestsPath 'C:\Maester\tests' -TagsDocPath 'C:\Maester\website\docs\tests\tags\readme.md'

    Updates the tags documentation file using specified paths for the repository root, tests directory, and tags documentation file.
#>
[CmdletBinding()]
param(
    # The path to the root of the repository.
    [Parameter()]
    [ValidateScript( { Test-Path $_ } )]
    [string]$RepoRoot = (Split-Path -Path $PSScriptRoot),

    # The path to the Maester tests directory. Defaults to tests within the repository root.
    [Parameter()]
    [ValidateScript( { Test-Path $_ } )]
    [string]$TestsPath = (Join-Path -Path (Split-Path -Path $PSScriptRoot) -ChildPath 'tests'),

    # The path to the tags documentation file to update. Defaults to website/docs/tests/tags/readme.md within the repository root.
    [Parameter()]
    [ValidateScript( { Test-Path (Split-Path $_ -Parent) } )]
    [string]$TagsDocPath = (Join-Path -Path (Split-Path -Path $PSScriptRoot) -ChildPath 'website/docs/tests/tags/readme.md')
)

#region Get Tag Inventory
# Dot-source the Get-MtTestInventory script (in lieu of importing the entire module).
try {
    $InventoryScript = Join-Path $RepoRoot 'powershell/public/Get-MtTestInventory.ps1'
    . $InventoryScript
} catch {
    throw "Failed to load Get-MtTestInventory.ps1 from $InventoryScript. $_"
}

# Get test and tag inventory
$Inventory = Get-MtTestInventory -Path $TestsPath

# Build list of tags counts for use as table rows.
$TagCounts = [System.Collections.Generic.List[pscustomobject]]::new()
foreach ($Item in $Inventory.GetEnumerator()) {
    $TagCounts.Add([pscustomobject]@{
            Tag   = $Item.Name
            Count = $Item.Value.Count
        })
}

function Add-OrUpdateTag {
    <#
    .SYNOPSIS
        Adds a new tag and its count to the list, or updates the count if the tag already exists in the list.
    #>
    param(
        # The tag to add or update in the list.
        [string]$Tag,

        # The count to add to the tag's existing count (or set if new).
        [int]$Count
    )

    # Check if the tag already exists in the TagCounts list.
    $Existing = $TagCounts | Where-Object { $_.Tag -eq $Tag }
    if ($Existing) {
        # Increment the count if it already exists in the list.
        foreach ($item in $Existing) {
            $item.Count += $Count
        }
    } else {
        # Add a new entry if the tag does not exist in the list.
        $TagCounts.Add([pscustomobject]@{
                Tag   = $Tag
                Count = $Count
            })
    }
} # end function Add-OrUpdateTag

#region Manually Add Tags
# Manually add and count tags from tests that fail discovery so counts remain accurate.
# For example, 'MT.1059' will always fail discovery unless connected to an environment that has implemented MDI.
Add-OrUpdateTag -Tag 'MT.1059' -Count 1
Add-OrUpdateTag -Tag 'MDI' -Count 1
#endregion Manually Add Tags

# Define groups for categorizing tags in the documentation.
$TagGroups = [ordered]@{
    'CIS'       = { param($t) $t.Tag -match '^CIS(\.|\s|$)|L1|L2' }
    'CISA'      = { param($t) $t.Tag -match '^CISA(\.|$)' -or $t.Tag -match '^MS\.' }
    'EIDSCA'    = { param($t) $t.Tag -match '^EIDSCA(\.|$)' }
    'ORCA'      = { param($t) $t.Tag -match '^ORCA(\.|$)' }
    'Maester'   = { param($t) $t.Tag -match '^(MT\.|Maester)' }
    'Ungrouped' = { param($t) $t.Tag -notmatch '^(CIS|L1|L2|CISA|MS\.|EIDSCA|ORCA|MT\.|Maester)' }
}
#endregion Get Tag Inventory


function ConvertTo-MarkdownTable {
    <#
    .SYNOPSIS
        Converts a list of tags and their counts into a markdown-formatted table.
    #>
    param(
        [string] $TagCategoryTitle,
        [System.Collections.Generic.List[PSCustomObject]] $Items
    )

    # Return null if there are no items to process.
    if (-not $Items -or $Items.Count -eq 0) { return $null }

    # Split items into multiple use (count > 1) and single use (count = 1) for the summary.
    $MultipleUse = $Items | Where-Object { $_.Count -gt 1 } | Sort-Object -Property Tag
    $SingleUse = $Items | Where-Object { $_.Count -eq 1 } | Sort-Object -Property Tag

    # Initialize a StringBuilder to construct the markdown table.
    $SB = [System.Text.StringBuilder]::new()
    [void]$SB.AppendLine("### $TagCategoryTitle")
    [void]$SB.AppendLine()

    # Only create table if there are tags used more than once.
    if ($MultipleUse) {
        [void]$SB.AppendLine('| Tag | Count |')
        [void]$SB.AppendLine('| :--- | ---: |')
        foreach ($i in $MultipleUse) {
            [void]$SB.AppendLine("| $($i.Tag) | $($i.Count) |")
        }
        [void]$SB.AppendLine()
    }

    # Add single-use tags as comma-separated list
    if ($SingleUse) {
        $singleTagList = ($SingleUse | ForEach-Object { $_.Tag }) -join ', '
        [void]$SB.AppendLine("**Individual tags**: $singleTagList")
        #[void]$SB.AppendLine()
    }

    # Return the constructed markdown string.
    return $SB.ToString()
} # end function ConvertTo-MarkdownTable

# Build markdown sections for each tag group.
$SectionBlocks = @()
foreach ($Key in $TagGroups.Keys) {
    $matched = $TagCounts | Where-Object { & $TagGroups[$Key] $_ }
    if ($matched) { $SectionBlocks += ConvertTo-MarkdownTable -TagCategoryTitle $Key -Items ([System.Collections.Generic.List[PSCustomObject]]$matched) }
}

# Join the section blocks into a single markdown string.
$SectionsText = ($SectionBlocks | Where-Object { $_ }) -join "`n"

#region Create Static Markdown Content
# Create the markdown front matter.
$FrontMatter = @"
---
id: overview
title: Tags Overview
sidebar_label: 🏷️ Tags
description: Overview of the tags used to identify and group related tests.
---

"@

# Create the introductory text for the tags documentation.
$Intro = @"
## Tags Overview

Tags are used by Maester to identify and group related tests. They can also be used to select specific tests to run or exclude during test execution. This makes them very useful, but they can also get in the way if too many tags are created. Our goal is to minimize the "signal to noise" ratio when it comes to tags by focusing on a few key areas:

- **Test Suites**: We use standardized tag categories for test suites that align with well-known benchmarks and baselines. This helps users quickly identify tests that align with these widely recognized standards or with Maester's own suite of tests:
  - **CIS Benchmarks**: Tags prefixed with `CIS` (e.g., `CIS.M365.1.1`, `CIS.Azure.3.2`)
  - **CISA & Microsoft Baseline**: Tags prefixed with `CISA` or `MS` (e.g., `CISA.M365.Baseline`, `MS.Azure.Baseline`)
  - **EIDSCA**: Tags prefixed with `EIDSCA` (e.g., `EIDSCA.EntraID.2.1`)
  - **ORCA**: Tags prefixed with `ORCA` (e.g., `ORCA.Exchange.1.1`)
  - **Maester**: Tags prefixed with `Maester` or `MT` (e.g., `MT.1001`, `MT.1024`)

- **Product Areas**: Tags related to specific products and services that are being tested:
  - Azure
  - Defender XDR
  - Entra ID
  - Exchange
  - Microsoft 365
  - SharePoint
  - Teams

- **Practices or Capabilities**: Tags that denote specific security practices or capabilities within the security domain, such as:
  - Authentication (May include related topics such as MFA, SSPR, etc.)
  - Conditional Access (CA)
  - Data Loss Prevention (DLP)
  - Extended Security Posture Management (XSPM)
  - Hybrid Identity
  - Privileged Access Management (PAM)
  - Privileged Identity Management (PIM)

### Recommendations for Tag Usage

Less is more! When creating or assigning tags to tests, consider the following best practices:

1. Assign one ``Test Suite`` tag per test to ensure clarity on which benchmark or baseline the test aligns with. This tag will usually go in the `Describe` block of a Pester test file.
2. Assign a ``Product Area`` tag to indicate which products or services the test is most relevant to. Limit these to 1-3 tags per test to avoid over-tagging.
3. Use ``Practice`` or ``Capability`` tags sparingly and only when they add significant value in categorizing the test. Avoid creating overly specific tags that may only apply to a single test.

## Tags Used

The tables below list every tag discovered via `Get-MtTestInventory`.

"@
#endregion Create Static Markdown Content

# Combine all parts into the final markdown content and write to the documentation file.
$Body = ($FrontMatter + $Intro + "`n" + $SectionsText) -join "`n"

# Create the directory for the tags documentation file if it doesn't exist.
if (-not (Test-Path -Path (Split-Path -Parent $TagsDocPath))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $TagsDocPath) -Force | Out-Null
}

# Write the final markdown content to the tags documentation file.
try {
    Set-Content -LiteralPath $TagsDocPath -Value $Body -Encoding UTF8
    Write-Host "Updated $TagsDocPath"
}
catch {
    Write-Error "Failed to write tags documentation to $TagsDocPath. $_"
}

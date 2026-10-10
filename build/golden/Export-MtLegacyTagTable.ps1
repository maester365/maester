<#
    .SYNOPSIS
    Generates the Maester 2.x tag table (Maester.LegacyTags.json) from the frozen tag snapshots.

    .DESCRIPTION
    In Maester 3.0 the built-in tests no longer carry taxonomy tags: product, feature, area, suite and
    severity are typed attributes (docs/proposals/maester-3.0-test-attributes.md, section 5). So that
    -Tag CA, -Tag CIS, -ExcludeTag MS.AAD.3.5 and every other 2.x tag keep selecting the same tests, the
    module ships a table that maps each 2.x tag to the IDs of the built-in tests that carried it.

    The table is derived from two frozen files and nothing else, so the output never changes with tests/:

      powershell/tests/fixtures/golden/tags-and-blocks.json    the tags of every built-in test in 2.x
      powershell/tests/fixtures/golden/tags-3.0-preview.json   tags the 3.0 previews added (for example AI)

    Rules:
      - A tag is matched case-insensitively; the table keeps the first spelling of the snapshot.
      - A 2.x ID that 3.0 renamed is written as its 3.0 ID ($RenamedIds below).
      - A tag that is the ID of the one test that carried it is left out: the engine always treats a
        built-in test's own ID as a selection tag.
      - Replacement is the typed selector that takes the tag's place, for the tags where there is an
        obvious one ($Replacements below, and -Severity for Severity:<value>). The engine names it in the
        warning it writes when a run selects through the tag.

    Tests added after 3.0 are not in the table. The file is generated once and is not edited by hand;
    powershell/tests/functions/golden/Golden.Tests.ps1 checks that it is what this script produces.

    .EXAMPLE
    ./build/golden/Export-MtLegacyTagTable.ps1

    Regenerates powershell/assets/Maester.LegacyTags.json.

    .EXAMPLE
    ./build/golden/Export-MtLegacyTagTable.ps1 -OutputPath ./out/Maester.LegacyTags.json

    Writes the table somewhere else (used by the drift test).
#>

[CmdletBinding()]
param (
    # Root of the Maester repository.
    [string] $RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path,

    # Output path for the generated table.
    [string] $OutputPath = "$PSScriptRoot/../../powershell/assets/Maester.LegacyTags.json"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -Path $RepoRoot).Path
$fixtures = Join-Path $RepoRoot 'powershell/tests/fixtures/golden'

# 2.x IDs that have another ID in 3.0.
$RenamedIds = @{
    'MT1060' = 'MT.1060' # The drift family: four Its per folder in 2.x, one native family in 3.0.
}

# The typed selector that takes the place of a tag. Only tags with an obvious one are listed.
$Replacements = [ordered]@{
    # Suites
    'Maester'           = '-Suite maester'
    'CISA'              = '-Suite cisa'
    'CIS'               = '-Suite cis'
    'EIDSCA'            = '-Suite eidsca'
    'ORCA'              = '-Suite orca'
    'XSPM'              = '-Suite xspm'
    # Products
    'AD'                = '-Product ad'
    'AZDO'              = '-Product azure-devops'
    'Azure'             = '-Product azure'
    'CopilotStudio'     = '-Product copilot-studio'
    'Defender'          = '-Product defender'
    'Entra'             = '-Product entra'
    'Exchange'          = '-Product exchange'
    'EXO'               = '-Product exchange'
    'GitHub'            = '-Product github'
    'Intune'            = '-Product intune'
    'Purview'           = '-Product purview'
    'SharePoint Online' = '-Product sharepoint'
    'Teams'             = '-Product teams'
    # Topics
    'CA'                = '-Feature conditional-access'
}

$ordinal = [System.StringComparer]::Ordinal
$ignoreCase = [System.StringComparer]::OrdinalIgnoreCase
$compare = [System.Comparison[string]] {
    param($a, $b)
    $c = $ignoreCase.Compare($a, $b)
    if ($c -ne 0) { return $c }
    $ordinal.Compare($a, $b)
}

# tag -> set of 3.0 test IDs, in the first spelling of each.
$spelling = [System.Collections.Generic.Dictionary[string, string]]::new($ignoreCase)
$carriers = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.HashSet[string]]]::new($ignoreCase)
function Add-Carrier {
    param([string] $Tag, [string] $Id)
    if ([string]::IsNullOrWhiteSpace($Tag) -or [string]::IsNullOrWhiteSpace($Id)) { return }
    if ($RenamedIds.ContainsKey($Id)) { $Id = $RenamedIds[$Id] }
    if (-not $carriers.ContainsKey($Tag)) {
        $spelling[$Tag] = $Tag
        $carriers[$Tag] = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
    }
    $null = $carriers[$Tag].Add($Id)
}

$snapshot = Get-Content -LiteralPath (Join-Path $fixtures 'tags-and-blocks.json') -Raw | ConvertFrom-Json
foreach ($entry in $snapshot.Entries) {
    foreach ($tag in @($entry.SelectionTags)) { Add-Carrier -Tag $tag -Id $entry.Id }
}
$preview = Get-Content -LiteralPath (Join-Path $fixtures 'tags-3.0-preview.json') -Raw | ConvertFrom-Json
foreach ($property in $preview.Tags.PSObject.Properties) {
    foreach ($id in @($property.Value)) { Add-Carrier -Tag $property.Name -Id $id }
}

$tags = [System.Collections.Generic.List[string]]::new([string[]]@($carriers.Keys))
$tags.Sort($compare)
$entries = foreach ($tag in $tags) {
    $ids = [System.Collections.Generic.List[string]]::new([string[]]@($carriers[$tag]))
    $ids.Sort($compare)
    # The own ID of a test: the engine adds it.
    if ($ids.Count -eq 1 -and $ignoreCase.Equals($ids[0], $tag)) { continue }
    $entry = [ordered]@{ Tag = $spelling[$tag] }
    $replacement = $Replacements.Keys | Where-Object { $ignoreCase.Equals($_, $tag) } | Select-Object -First 1
    if ($replacement) { $entry.Replacement = $Replacements[$replacement] }
    elseif ($tag -match '^Severity:\s*(?<value>Critical|High|Medium|Low|Info)$') {
        $value = $Matches['value']
        $entry.Replacement = "-Severity $($value.Substring(0, 1).ToUpperInvariant())$($value.Substring(1).ToLowerInvariant())"
    }
    $entry.Tests = $ids.ToArray()
    $entry
}
$unused = @($Replacements.Keys | Where-Object { -not $carriers.ContainsKey($_) })
if ($unused.Count -gt 0) { throw "These tags have a replacement but are not in the snapshots: $($unused -join ', ')." }

$document = [ordered]@{
    SchemaVersion = '1.0'
    Description   = 'Maester 2.x tags of the built-in tests: each tag, the typed selector that replaces it where there is one, and the IDs of the tests that carried it. Used only to resolve -Tag and -ExcludeTag. Generated by build/golden/Export-MtLegacyTagTable.ps1; never hand-edit.'
    Tags          = @($entries)
}
$json = (ConvertTo-Json -InputObject $document -Depth 5) -replace "`r`n", "`n"
$null = New-Item -Path (Split-Path -Path $OutputPath -Parent) -ItemType Directory -Force
[System.IO.File]::WriteAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath), $json.TrimEnd("`n") + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Verbose "Wrote $(@($entries).Count) tags to $OutputPath"

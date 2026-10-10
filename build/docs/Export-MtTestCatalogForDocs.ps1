<#
    .SYNOPSIS
    Exports the built-in Maester test catalog to JSON for the website test-docs generator.

    .DESCRIPTION
    Imports the Maester module from source (powershell/Maester.psd1), reads every built-in native test
    with Get-MtTest and writes its metadata to a JSON file. website/scripts/generate-test-docs.mjs reads
    that file, plus each test's Test.<ID>.md, to build the pages in website/docs/tests/.

    Each test has its attributes (Product, RelatedProduct, Feature, Area and ResourceType as taxonomy keys),
    the derived Block, Suite and Source, and LegacyTag: the tags it carried in Maester 2.x, which -Tag still
    matches. Taxonomy at the top level gives the display names of the keys and ATT&CK techniques the tests use.

    No tenant connection is needed and no test code is run. Importing the module requires
    Microsoft.Graph.Authentication to be installed (it is a RequiredModule of Maester).

    The output is deterministic: tests are sorted by ID (ordinal, case-insensitive), paths are
    repository-relative with forward slashes, and the file is UTF-8 without BOM with LF line endings.

    .PARAMETER OutputPath
    Where to write the JSON file. Defaults to website/.generated/test-catalog.json (git-ignored).

    .EXAMPLE
    ./build/docs/Export-MtTestCatalogForDocs.ps1

    Writes website/.generated/test-catalog.json, then `npm run generate-test-docs` (in website/) uses it.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..')).Path
if (-not $OutputPath) { $OutputPath = Join-Path -Path $repoRoot -ChildPath 'website' -AdditionalChildPath '.generated', 'test-catalog.json' }

Import-Module (Join-Path -Path $repoRoot -ChildPath 'powershell' -AdditionalChildPath 'Maester.psd1') -Force -WarningAction SilentlyContinue

function ConvertTo-RepoPath {
    param([string] $Path)
    if (-not $Path) { return '' }
    $full = [System.IO.Path]::GetFullPath($Path)
    return [System.IO.Path]::GetRelativePath($repoRoot, $full).Replace('\', '/')
}

function ConvertTo-StringArray {
    param($Value)
    return , @(@($Value) | Where-Object { $null -ne $_ -and "$_" -ne '' } | ForEach-Object { "$_" })
}

$tests = @(Get-MtTest | Where-Object { $_.BuiltIn })
$invalid = @($tests | Where-Object { -not $_.IsValid })
if ($invalid.Count -gt 0) {
    $list = ($invalid | ForEach-Object { "$($_.Id): $(@($_.Errors | ForEach-Object { $_.Message ?? "$_" }) -join '; ')" }) -join [Environment]::NewLine
    throw "Get-MtTest reported $($invalid.Count) invalid built-in test(s):$([Environment]::NewLine)$list"
}

$comparer = [System.StringComparer]::OrdinalIgnoreCase
$sorted = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::OrderBy([object[]]$tests, [Func[object, string]] { param($t) $t.Id }, $comparer))

$module = Get-Module Maester
$catalog = foreach ($t in $sorted) {
    [ordered]@{
        Id                 = $t.Id
        Title              = $t.Title
        Suite              = $t.Suite
        Source             = $t.Source
        Block              = $t.Block
        Product            = if ($t.Product) { "$($t.Product)" } else { '' }
        RelatedProduct     = ConvertTo-StringArray $t.RelatedProduct
        Feature            = if ($t.Feature) { "$($t.Feature)" } else { '' }
        Area               = if ($t.Area) { "$($t.Area)" } else { '' }
        ResourceType       = if ($t.ResourceType) { "$($t.ResourceType)" } else { '' }
        Severity           = $t.Severity
        UserImpact         = if ($t.UserImpact) { "$($t.UserImpact)" } else { '' }
        ImplementationCost = if ($t.ImplementationCost) { "$($t.ImplementationCost)" } else { '' }
        Mitre              = ConvertTo-StringArray $t.Mitre
        Control            = ConvertTo-StringArray $t.Control
        Service            = ConvertTo-StringArray $t.Service
        License            = ConvertTo-StringArray $t.License
        Permission         = ConvertTo-StringArray $t.Permission
        Lifecycle          = "$($t.Lifecycle)"
        ReplacedBy         = if ($t.ReplacedBy) { "$($t.ReplacedBy)" } else { '' }
        LongRunning        = [bool]$t.LongRunning
        InstanceSource     = if ($t.InstanceSource) { "$($t.InstanceSource)" } else { '' }
        Tag                = ConvertTo-StringArray $t.Tag
        LegacyTag          = ConvertTo-StringArray (& $module { param($test) (Get-MtSelectionTag -Test $test).Legacy } $t)
        Author             = ConvertTo-StringArray $t.Author
        Contributor        = ConvertTo-StringArray $t.Contributor
        HelpUrl            = if ($t.HelpUrl) { "$($t.HelpUrl)" } else { '' }
        FunctionName       = $t.FunctionName
        File               = ConvertTo-RepoPath $t.File
        MarkdownPath       = ConvertTo-RepoPath $t.MarkdownPath
    }
}
$taxonomy = & $module { param($tests) Get-MtResultTaxonomy -InputObject $tests } $sorted

$json = ConvertTo-Json -InputObject ([ordered]@{ Taxonomy = $taxonomy; Tests = @($catalog) }) -Depth 6
$json = $json.Replace("`r`n", "`n") + "`n"
$outDir = Split-Path $OutputPath -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
[System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutputPath), $json, [System.Text.UTF8Encoding]::new($false))
Write-Information -InformationAction Continue "Exported $(@($catalog).Count) built-in tests to $(ConvertTo-RepoPath $OutputPath)."

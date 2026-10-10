<#
    .SYNOPSIS
    Regenerates the Maester 2.x golden fixtures (tags and blocks, selection, config layouts).

    .DESCRIPTION
    Freezes today's (2.x) behaviour so later Maester 3.0 milestones can prove parity
    (design: docs/proposals/maester-3.0-design.md, sections 4, 7 and 15.2).

    Nothing here needs a tenant and no test body is executed:

    tags-and-blocks.json
        Every It in tests/**/*.Tests.ps1 (tests/Custom excluded), found by Pester discovery
        (Run.SkipRun = $true). For each It: Id, Name, Block, SelectionTags, ResultTags, File, Line.
          - Id and Block are computed exactly as ConvertTo-MtMaesterResult does (Id: text before the
            first colon after stripping the 'See https' suffix; Block: $test.Block.ExpandedName).
          - SelectionTags: the tags Pester filters on (tags of every ancestor Describe/Context plus the
            It tags), de-duplicated and sorted case-insensitively.
          - ResultTags: the Tag array ConvertTo-MtMaesterResult writes today,
            @($test.Block.Tag + $test.Tag | Select-Object -Unique). Only the immediate parent block's
            tags are included, so tests nested in a Context lose their Describe tags.
        Its whose name is built at run time (an expandable string or a '<template>') are families
        (MT.1024, MT.1033, MT.1034, MT.1059, MT1060). They are recorded once, by literal ID prefix,
        with "Family": true, from the AST. Discovery-time tenant calls are neutralised by a stub
        module; any file whose discovery still fails falls back to an AST scan and is listed in _meta.

    selection.json
        For a list of Invoke-Maester command lines, the Pester filter Invoke-Maester builds and the IDs
        it selects. The filter is captured from the real Invoke-Maester code path: Invoke-Pester is
        shadowed inside the Maester module scope so the configuration is captured instead of run.
        The captured filter is then applied by a real Pester discovery of the built-in tests. Family
        entries (invisible to discovery without a tenant) are selected with a replica of Pester's tag
        filter, which is verified against Pester's own result for every discovered test.

    config-layouts/<layout>/expected.json
        For each committed layout folder, the config file(s) the real 2.x Get-MtMaesterConfig picks
        and the effective GlobalSettings and Severity for a few IDs, with and without a tenant ID.
        Get-MtMaesterTestFolderPath is pointed at the repository's tests/ folder, which is what the
        build ships as maester-tests/.

    The output is deterministic: ordinal case-insensitive sorting, stable JSON, LF line endings,
    UTF-8 without BOM. Run it in a fresh process (it imports the source module and a stub module).

    .EXAMPLE
    pwsh -NoProfile -File ./build/golden/Export-MtGoldenFixture.ps1

    Regenerates every golden file under powershell/tests/fixtures/golden.

    .EXAMPLE
    pwsh -NoProfile -File ./build/golden/Export-MtGoldenFixture.ps1 -OutputPath ./out

    Writes the golden files to ./out instead (used by the drift test). Config layout inputs are
    always read from the committed fixture folders.
#>

[CmdletBinding()]
param (
    # Root of the Maester repository.
    [string] $RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path,

    # Folder the golden files are written to.
    [string] $OutputPath = "$PSScriptRoot/../../powershell/tests/fixtures/golden"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

$RepoRoot = (Resolve-Path $RepoRoot).Path
$TestsRoot = Join-Path $RepoRoot 'tests'
$LayoutsRoot = Join-Path $RepoRoot 'powershell/tests/fixtures/golden/config-layouts'
$null = New-Item -Path $OutputPath -ItemType Directory -Force
$OutputPath = (Resolve-Path $OutputPath).Path

# Tenant ID used by the tenant-specific config layouts.
$GoldenTenantId = '11111111-2222-3333-4444-555555555555'

# IDs whose effective severity is recorded for each config layout.
$GoldenSeverityIds = @('MT.1001', 'MT.1003', 'MT.1005')

# Commands called at discovery time (BeforeDiscovery, -Skip and -ForEach expressions) that need a tenant.
$StubbedCommands = @('Add-MtTestResultDetail', 'Get-MtAuthenticationMethodPolicyConfig', 'Get-MtLicenseInformation', 'Get-MtUser', 'Invoke-MtGraphRequest')

$Ordinal = [System.StringComparer]::Ordinal
$IgnoreCase = [System.StringComparer]::OrdinalIgnoreCase

#region Helpers
function Get-RepoRelativePath {
    param([string] $Path)
    if ([string]::IsNullOrEmpty($Path)) { return $null }
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $full = $full.Substring($RepoRoot.Length).TrimStart('\', '/')
    }
    return ($full -replace '\\', '/')
}

function Get-SortedString {
    # Sorts strings ordinal case-insensitively (ties broken ordinally) so output is culture independent.
    param([object[]] $InputObject)
    $items = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $InputObject) { if ($null -ne $item) { $items.Add([string]$item) } }
    $items.Sort([System.Comparison[string]] {
            param($a, $b)
            $c = $IgnoreCase.Compare($a, $b)
            if ($c -ne 0) { return $c }
            return $Ordinal.Compare($a, $b)
        })
    return $items.ToArray()
}

function Get-UniqueTagSet {
    # De-duplicates case-insensitively (first spelling wins) and sorts; this is how Pester's -like matching sees tags.
    param([object[]] $InputObject)
    $seen = [System.Collections.Generic.HashSet[string]]::new($IgnoreCase)
    $unique = foreach ($tag in $InputObject) {
        if ($null -ne $tag -and $seen.Add([string]$tag)) { [string]$tag }
    }
    return Get-SortedString @($unique)
}

function Get-MaesterTestId {
    # Mirrors the Id computation in powershell/internal/report/ConvertTo-MtMaesterResult.ps1 (without the run-time TestTitle override).
    param([string] $Name)
    $start = $Name.IndexOf('See https')
    if ($start -gt 0) { $Name = $Name.Substring(0, $start).Trim() }
    $titleStart = $Name.IndexOf(':')
    if ($titleStart -gt 0) { return $Name.Substring(0, $titleStart).Trim() }
    return $Name
}

function Test-GoldenTagFilter {
    # Replica of Pester 5 Test-ShouldRun for tags: ExcludeTag on any ancestor or own tag wins, else
    # any -like match of Tag on an ancestor or own tag includes; no Tag filter includes everything.
    param([string[]] $Tags, [string[]] $Tag, [string[]] $ExcludeTag)
    foreach ($f in @($ExcludeTag | Where-Object { $_ })) {
        foreach ($t in $Tags) { if ($t -like $f) { return $false } }
    }
    $include = @($Tag | Where-Object { $_ })
    if ($include.Count -eq 0) { return $true }
    foreach ($f in $include) {
        foreach ($t in $Tags) { if ($t -like $f) { return $true } }
    }
    return $false
}

function ConvertTo-GoldenJson {
    param([object] $InputObject)
    $json = ConvertTo-Json -InputObject $InputObject -Depth 32
    return (($json -replace "`r`n", "`n").TrimEnd("`n") + "`n")
}

function Write-GoldenFile {
    param([string] $Path, [string] $Content)
    $null = New-Item -Path (Split-Path $Path -Parent) -ItemType Directory -Force
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
    Write-Verbose "Wrote $Path"
}

function Get-BuiltInTestFile {
    Get-ChildItem -Path $TestsRoot -Recurse -File -Filter '*.ps1' |
        Where-Object { $_.Name -like '*.Tests.ps1' } |
        Where-Object { (Get-RepoRelativePath $_.FullName) -notlike 'tests/Custom/*' }
}

function Get-BuiltInTestFolder {
    # Pester Run.Path for the built-in tests: every folder under tests/ except Custom.
    Get-ChildItem -Path $TestsRoot -Directory | Where-Object { $_.Name -ne 'Custom' } | ForEach-Object FullName | Sort-Object
}
#endregion Helpers

#region AST scan
function Get-AstCommandArgument {
    # Splits a Pester block command (Describe/Context/It) into its name element, tag elements and parameters.
    param([System.Management.Automation.Language.CommandAst] $Command)
    $result = @{ Name = $null; Tags = @(); Parameters = @() }
    $elements = $Command.CommandElements
    $consumes = 'Name', 'Tag', 'Tags', 'ForEach', 'TestCases', 'Skip', 'Fixture'
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $element = $elements[$i]
        if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
            $paramName = $element.ParameterName
            $result.Parameters += $paramName
            $argument = $element.Argument
            if ($null -eq $argument -and $paramName -in $consumes -and $paramName -ne 'Skip' -and ($i + 1) -lt $elements.Count) {
                $i++
                $argument = $elements[$i]
            }
            if ($paramName -in 'Tag', 'Tags' -and $argument) {
                if ($argument -is [System.Management.Automation.Language.ArrayLiteralAst]) {
                    $result.Tags += $argument.Elements
                } else {
                    $result.Tags += $argument
                }
            } elseif ($paramName -eq 'Name' -and $argument) {
                $result.Name = $argument
            }
            continue
        }
        if ($element -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { continue }
        if ($null -eq $result.Name) { $result.Name = $element }
    }
    return $result
}

function Get-AstTagValue {
    # Returns @{ Static = [string[]]; Dynamic = [string[]] } for tag argument elements.
    param([object[]] $Elements)
    $static = @(); $dynamic = @()
    foreach ($element in $Elements) {
        if ($element -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and $element.NestedExpressions.Count -gt 0) {
            $dynamic += $element.Extent.Text
            continue
        }
        try {
            $static += @($element.SafeGetValue() | ForEach-Object { [string]$_ })
        } catch {
            $dynamic += $element.Extent.Text
        }
    }
    return @{ Static = $static; Dynamic = $dynamic }
}

function Get-AstItInfo {
    # Every It in a file with its static name, tags, ancestor blocks and whether it is a family.
    param([System.IO.FileInfo] $File)
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors) { throw "Failed to parse $($File.FullName): $($parseErrors.Message -join '; ')" }
    $its = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'It'
        }, $true)
    foreach ($it in $its) {
        $itArgs = Get-AstCommandArgument -Command $it
        $nameAst = $itArgs.Name
        $isDynamicName = $nameAst -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and $nameAst.NestedExpressions.Count -gt 0
        $nameText = if ($nameAst -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
            $nameAst -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) { $nameAst.Value } else { $nameAst.Extent.Text }
        $isTemplate = $nameText -match '<[^>]+>'
        $itTags = Get-AstTagValue -Elements $itArgs.Tags

        $blocks = @()
        $ancestor = $it.Parent
        while ($null -ne $ancestor) {
            if ($ancestor -is [System.Management.Automation.Language.CommandAst] -and $ancestor.GetCommandName() -in 'Describe', 'Context') {
                $blockArgs = Get-AstCommandArgument -Command $ancestor
                $blockTags = Get-AstTagValue -Elements $blockArgs.Tags
                $blockName = $blockArgs.Name
                $blocks += [pscustomobject]@{
                    Name        = if ($blockName.PSObject.Properties.Name -contains 'Value') { $blockName.Value } else { $blockName.Extent.Text }
                    StaticTags  = $blockTags.Static
                    DynamicTags = $blockTags.Dynamic
                    HasForEach  = [bool]($blockArgs.Parameters | Where-Object { $_ -in 'ForEach', 'TestCases' })
                }
            }
            $ancestor = $ancestor.Parent
        }

        [pscustomobject]@{
            File        = Get-RepoRelativePath $File.FullName
            Line        = $it.Extent.StartLineNumber
            Name        = $nameText
            IsFamily    = $isDynamicName -or $isTemplate
            StaticTags  = $itTags.Static
            DynamicTags = $itTags.Dynamic
            Blocks      = $blocks # nearest first
        }
    }
}

function Get-FamilyPrefix {
    param([string] $Name)
    $cut = $Name.IndexOfAny([char[]]@('$', '<'))
    $prefix = if ($cut -ge 0) { $Name.Substring(0, $cut) } else { $Name }
    return $prefix.TrimEnd('.', ' ')
}
#endregion AST scan

#region Discovery
function Invoke-GoldenDiscovery {
    # Pester discovery of the built-in tests; nothing is executed.
    param([string[]] $Tag, [string[]] $ExcludeTag)
    $config = New-PesterConfiguration
    $config.Run.Path = @(Get-BuiltInTestFolder)
    $config.Run.SkipRun = $true
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'None'
    if ($Tag) { $config.Filter.Tag = $Tag }
    if ($ExcludeTag) { $config.Filter.ExcludeTag = $ExcludeTag }
    Invoke-Pester -Configuration $config -WarningAction SilentlyContinue -InformationAction SilentlyContinue 3>$null 6>$null
}

function Get-FailedContainerFile {
    param($PesterResult)
    @($PesterResult.Containers | Where-Object { $_.Result -eq 'Failed' } | ForEach-Object { Get-RepoRelativePath $_.Item.FullName })
}
#endregion Discovery

Import-Module Pester -MinimumVersion 5.7.1
Import-Module (Join-Path $RepoRoot 'powershell/Maester.psd1') -Force -WarningAction SilentlyContinue
$maesterModule = Get-Module Maester

#region Tags and blocks
Write-Verbose 'Scanning test files with the AST'
$testFiles = @(Get-BuiltInTestFile)
$astIts = @(foreach ($file in $testFiles) { Get-AstItInfo -File $file })
$astByKey = @{}
foreach ($astIt in $astIts) { $astByKey["$($astIt.File):$($astIt.Line)"] = $astIt }

Write-Verbose 'Discovering without stubs (records which files fail discovery without a tenant)'
$plainDiscovery = Invoke-GoldenDiscovery
$failWithoutTenant = @(Get-SortedString (Get-FailedContainerFile $plainDiscovery))

Write-Verbose 'Discovering with stubbed tenant commands'
$stubBody = ($StubbedCommands | ForEach-Object {
        "function $_ { [CmdletBinding()] param([Parameter(ValueFromRemainingArguments = `$true)] `$Rest) if ('$_' -eq 'Invoke-MtGraphRequest') { return @{ value = @() } } }"
    }) -join "`n"
$stubModule = New-Module -Name MaesterGoldenStub -ScriptBlock ([scriptblock]::Create($stubBody + "`nExport-ModuleMember -Function *"))
Import-Module $stubModule -Global -Force -WarningAction SilentlyContinue

$discovery = Invoke-GoldenDiscovery
$fallbackFiles = @(Get-SortedString (Get-FailedContainerFile $discovery))

$entries = [System.Collections.Generic.List[object]]::new()
$familyKeys = [System.Collections.Generic.HashSet[string]]::new()
$tagMismatches = [System.Collections.Generic.List[string]]::new()
$droppedFamilyInstances = 0

foreach ($test in $discovery.Tests) {
    $file = Get-RepoRelativePath $test.ScriptBlock.File
    if ($file -in $fallbackFiles) { continue }
    $key = "${file}:$($test.StartLine)"
    $astIt = $astByKey[$key]
    if ($null -eq $astIt) { throw "Discovered test '$($test.ExpandedName)' at $key has no matching It in the AST scan." }
    if ($astIt.IsFamily) { $droppedFamilyInstances++; continue }

    $selectionTags = @($test.Tag)
    $block = $test.Block
    while ($null -ne $block -and -not $block.IsRoot) {
        $selectionTags += @($block.Tag)
        $block = $block.Parent
    }
    # Exactly what ConvertTo-MtMaesterResult writes to the result's Tag array.
    $resultTags = @($test.Block.Tag + $test.Tag | Select-Object -Unique)

    # Self-check: static AST tags must agree with what Pester discovered.
    $astTags = @($astIt.StaticTags) + @($astIt.Blocks | ForEach-Object { $_.StaticTags })
    if ((@(Get-UniqueTagSet $astTags) -join '|') -ne (@(Get-UniqueTagSet $selectionTags) -join '|')) {
        $tagMismatches.Add($key)
    }

    $entries.Add([ordered]@{
            Id            = Get-MaesterTestId -Name $test.ExpandedName
            Name          = $test.ExpandedName
            Block         = $test.Block.ExpandedName
            SelectionTags = @(Get-UniqueTagSet $selectionTags)
            ResultTags    = @($resultTags | ForEach-Object { [string]$_ })
            File          = $file
            Line          = $test.StartLine
            Family        = $false
        })
}

foreach ($astIt in $astIts) {
    $isFallback = $astIt.File -in $fallbackFiles
    if (-not $astIt.IsFamily -and -not $isFallback) { continue }
    $parent = $astIt.Blocks | Select-Object -First 1
    $selectionTags = @($astIt.StaticTags) + @($astIt.Blocks | ForEach-Object { $_.StaticTags })
    $dynamicTags = @($astIt.DynamicTags) + @($astIt.Blocks | ForEach-Object { $_.DynamicTags })
    $resultTags = @(@($parent.StaticTags) + @($astIt.StaticTags) | Select-Object -Unique)
    $entry = [ordered]@{
        Id            = if ($astIt.IsFamily) { Get-FamilyPrefix -Name $astIt.Name } else { Get-MaesterTestId -Name $astIt.Name }
        Name          = $astIt.Name
        Block         = $parent.Name
        SelectionTags = @(Get-UniqueTagSet $selectionTags)
        ResultTags    = @($resultTags | ForEach-Object { [string]$_ })
        File          = $astIt.File
        Line          = $astIt.Line
        Family        = [bool]$astIt.IsFamily
    }
    if ($dynamicTags.Count -gt 0) { $entry.DynamicTags = @(Get-SortedString $dynamicTags) }
    if ($astIt.IsFamily) { $null = $familyKeys.Add("$($astIt.File):$($astIt.Line)") }
    $entries.Add($entry)
}

if ($tagMismatches.Count -gt 0) {
    throw "AST tags differ from Pester-discovered tags for: $($tagMismatches -join ', ')"
}

# Native tests (Maester 3.0): a migrated check is no longer a Pester It, so its entry comes from the
# catalog: Block is the attribute's Category and the tags are the effective tag set (suite tags + Id +
# Tag + Preview/LongRunning), which is what both selection and the result use.
$nativeCatalog = @(& $maesterModule { Get-MtTestCatalog -Refresh })
foreach ($t in $nativeCatalog) {
    $tags = @(Get-UniqueTagSet @($t.EffectiveTag))
    $entries.Add([ordered]@{
            Id            = $t.Id
            Name          = "$($t.Id): $($t.Title)"
            Block         = $t.Category
            SelectionTags = $tags
            ResultTags    = @($t.EffectiveTag)
            File          = Get-RepoRelativePath $t.File
            Line          = [int]$t.Line
            Family        = [bool]$t.InstanceSource
            Format        = 'Native'
        })
}

$entries.Sort([System.Comparison[object]] {
        param($a, $b)
        foreach ($k in 'Id', 'File') {
            $c = $IgnoreCase.Compare([string]$a[$k], [string]$b[$k])
            if ($c -eq 0) { $c = $Ordinal.Compare([string]$a[$k], [string]$b[$k]) }
            if ($c -ne 0) { return $c }
        }
        return $a.Line.CompareTo($b.Line)
    })

$instanceEntries = @($entries | Where-Object { -not $_.Family })
$familyEntries = @($entries | Where-Object { $_.Family })
$duplicateIds = @(Get-SortedString @($instanceEntries | Group-Object { $_.Id } | Where-Object Count -gt 1 | ForEach-Object Name))
$contextDroppedTags = @(Get-SortedString @($entries | Where-Object {
        (@(Get-UniqueTagSet $_.ResultTags) -join '|') -ne ($_.SelectionTags -join '|')
    } | ForEach-Object { $_.Id } | Select-Object -Unique))

$tagsDocument = [ordered]@{
    _meta   = [ordered]@{
        Description                  = 'Maester 2.x golden: Id, Block and tags of every built-in It. Regenerate with build/golden/Export-MtGoldenFixture.ps1; never hand-edit.'
        Source                       = 'tests/**/*.Tests.ps1 (tests/Custom excluded), Pester discovery with Run.SkipRun'
        IdRule                       = 'ConvertTo-MtMaesterResult: strip the "See https" suffix, then the text before the first colon (whole name if none). A run-time TestTitle from Add-MtTestResultDetail can still change it.'
        BlockRule                    = 'ConvertTo-MtMaesterResult: $test.Block.ExpandedName (the immediate parent Describe or Context).'
        SelectionTagsRule            = 'Tags Pester filters on: every ancestor Describe/Context tag plus the It tags; de-duplicated and sorted case-insensitively.'
        ResultTagsRule               = 'ConvertTo-MtMaesterResult: @($test.Block.Tag + $test.Tag | Select-Object -Unique); immediate parent block only, order preserved.'
        FamilyRule                   = 'Its whose name is an expandable string or contains a <template> are one Family entry keyed by the literal ID prefix; DynamicTags lists tags computed at run time.'
        StubbedCommands              = @(Get-SortedString $StubbedCommands)
        FilesFailingDiscoveryWithoutTenant = $failWithoutTenant
        FallbackFiles                = $fallbackFiles
        ItCount                      = $entries.Count
        TestCount                    = $instanceEntries.Count
        UniqueIdCount                = @($instanceEntries | ForEach-Object { $_.Id } | Select-Object -Unique).Count
        FamilyCount                  = $familyEntries.Count
        FamilyPrefixes               = @(Get-UniqueTagSet @($familyEntries | ForEach-Object { $_.Id }))
        DuplicateIds                 = $duplicateIds
        IdsWithResultTagsDifferentFromSelectionTags = $contextDroppedTags
    }
    Entries = $entries.ToArray()
}
# tags-and-blocks.json in the repository is the frozen 2.x snapshot that migrated checks are compared
# against; it is written only to an explicit -OutputPath (the drift test regenerates it there).
if ($PSBoundParameters.ContainsKey('OutputPath')) {
    Write-GoldenFile -Path (Join-Path $OutputPath 'tags-and-blocks.json') -Content (ConvertTo-GoldenJson $tagsDocument)
}
#endregion Tags and blocks

#region Selection
function Get-InvokeMaesterSelection {
    # Runs the real Invoke-Maester with -DryRun and returns its result (rows and the effective tag filter).
    param([hashtable] $Parameters, [string] $WorkDir)
    $common = @{
        SkipGraphConnect = $true
        NonInteractive   = $true
        DisableTelemetry = $true
        SkipVersionCheck = $true
        NoLogo           = $true
        DryRun           = $true
        PassThru         = $true
        OutputFolder     = (Join-Path $WorkDir 'test-results')
    }
    Push-Location $WorkDir
    try {
        $result = Invoke-Maester @Parameters @common -WarningAction SilentlyContinue 3>$null 6>$null
    } finally {
        Pop-Location
    }
    if ($null -eq $result) { throw "Invoke-Maester did not produce a result for case parameters: $($Parameters | ConvertTo-Json -Compress)" }
    $result
}

# Reason codes of tests that selection leaves out. OptInServiceNotConnected stands for 2.x adding AD to
# Filter.ExcludeTag when Active Directory is not connected.
$NotSelectedReasons = @('NotSelected', 'NotListed', 'Preview', 'LongRunning', 'ExcludedByTag', 'ExcludedById', 'DisabledByConfig', 'OptInServiceNotConnected')

# An empty user folder: every built-in test is native and runs from the module.
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) "maester-golden-$([guid]::NewGuid().ToString('N'))"
$null = New-Item -Path (Join-Path $workDir 'tests') -ItemType Directory -Force
$selectionCases = @(
    [ordered]@{ Name = 'Default'; Parameters = [ordered]@{} }
    [ordered]@{ Name = 'Tag CIS'; Parameters = [ordered]@{ Tag = @('CIS') } }
    [ordered]@{ Name = 'Tag LongRunning'; Parameters = [ordered]@{ Tag = @('LongRunning') } }
    [ordered]@{ Name = 'Tag CAWhatIf'; Parameters = [ordered]@{ Tag = @('CAWhatIf') } }
    [ordered]@{ Name = 'ExcludeTag EIDSCA'; Parameters = [ordered]@{ ExcludeTag = @('EIDSCA') } }
    [ordered]@{ Name = 'IncludeLongRunning'; Parameters = [ordered]@{ IncludeLongRunning = $true } }
    [ordered]@{ Name = 'IncludePreview'; Parameters = [ordered]@{ IncludePreview = $true } }
    [ordered]@{ Name = 'IncludeLongRunning IncludePreview'; Parameters = [ordered]@{ IncludeLongRunning = $true; IncludePreview = $true } }
    [ordered]@{ Name = 'Tag CIS E3 Level 1'; Parameters = [ordered]@{ Tag = @('CIS E3 Level 1') } }
    [ordered]@{ Name = 'Tag MT.1068'; Parameters = [ordered]@{ Tag = @('MT.1068') } }
    [ordered]@{ Name = 'Tag CA IncludeLongRunning (help example)'; Parameters = [ordered]@{ Tag = @('CA'); IncludeLongRunning = $true } }
    [ordered]@{
        Name                = 'PesterConfiguration Run.Path, Filter.Tag CA, Filter.ExcludeTag App (help example)'
        Parameters          = [ordered]@{}
        PesterConfiguration = [ordered]@{ 'Run.Path' = './tests/Maester'; 'Filter.Tag' = @('CA'); 'Filter.ExcludeTag' = @('App') }
    }
    [ordered]@{
        Name                = 'PesterConfiguration Filter.ExcludeTag EIDSCA'
        Parameters          = [ordered]@{}
        PesterConfiguration = [ordered]@{ 'Filter.ExcludeTag' = @('EIDSCA') }
    }
    [ordered]@{
        Name                = 'PesterConfiguration Filter.ExcludeTag EIDSCA with IncludeLongRunning IncludePreview'
        Parameters          = [ordered]@{ IncludeLongRunning = $true; IncludePreview = $true }
        PesterConfiguration = [ordered]@{ 'Filter.ExcludeTag' = @('EIDSCA') }
    }
)

$selectionResults = [System.Collections.Generic.List[object]]::new()
$familyAlias = @{ 'MT.1024' = 'MT.1024'; 'MT.1033' = 'MT.1033'; 'MT.1034' = 'MT.1034'; 'MT.1059' = 'MT.1059'; 'MT.1060' = 'MT1060' }
$familyIds = @($familyAlias.Keys)
try {
    foreach ($case in $selectionCases) {
        Write-Verbose "Selection case: $($case.Name)"
        $parameters = @{}
        foreach ($k in $case.Parameters.Keys) { $parameters[$k] = $case.Parameters[$k] }
        if ($case.PesterConfiguration) {
            $pc = New-PesterConfiguration
            foreach ($k in $case.PesterConfiguration.Keys) {
                $section, $option = $k -split '\.', 2
                $pc.$section.$option = $case.PesterConfiguration[$k]
            }
            $parameters.PesterConfiguration = $pc
        }

        $run = Get-InvokeMaesterSelection -Parameters $parameters -WorkDir $workDir
        $filterTag = @($run.Selection.IncludeTag | Where-Object { $_ })
        $filterExcludeTag = @($run.Selection.ExcludeTag | Where-Object { $_ })
        $selectedIds = @(); $selectedFamilies = @()
        foreach ($row in @($run.Tests)) {
            if ($row.Result -eq 'NotRun' -and $row.ReasonCode -in $NotSelectedReasons) { continue }
            $id = if ($row.ParentId) { $row.ParentId } else { $row.Id }
            if ($familyIds -contains $id) { $selectedFamilies += $familyAlias[$id] } else { $selectedIds += $id }
        }
        $result = [ordered]@{
            Name       = $case.Name
            Parameters = $case.Parameters
        }
        if ($case.PesterConfiguration) { $result.PesterConfiguration = $case.PesterConfiguration }
        $result.Filter = [ordered]@{
            Tag        = $filterTag
            ExcludeTag = $filterExcludeTag
        }
        $selectedIdSet = @(Get-UniqueTagSet $selectedIds)
        $result.SelectedCount = $selectedIdSet.Count
        $result.SelectedFamilies = @(Get-UniqueTagSet $selectedFamilies)
        $result.SelectedIds = $selectedIdSet
        $selectionResults.Add($result)
    }
} finally {
    Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

$selectionDocument = [ordered]@{
    _meta = [ordered]@{
        Description     = 'Maester 2.x golden: Pester filter built by Invoke-Maester and the IDs it selects. Regenerate with build/golden/Export-MtGoldenFixture.ps1; never hand-edit.'
        FilterSource    = 'The include and exclude tags of the real Invoke-Maester run context, run with -DryRun -SkipGraphConnect in an empty folder.'
        SelectionSource = 'The rows of that dry run that selection did not leave out (any reason other than NotSelected, NotListed, Preview, LongRunning, ExcludedByTag, ExcludedById, DisabledByConfig or OptInServiceNotConnected). Families are listed by their 2.x prefix.'
        Assumptions     = @(
            'Not connected to Active Directory, so Invoke-Maester appends AD to Filter.ExcludeTag.',
            'Run.Path "." is the installed tests folder (repo tests/ without Custom); "./tests/<x>" maps to repo tests/<x>.',
            'SelectedIds are unique IDs; an ID shared by several Its is listed once. Families are listed by prefix in SelectedFamilies.'
        )
    }
    Cases = $selectionResults.ToArray()
}
Write-GoldenFile -Path (Join-Path $OutputPath 'selection.json') -Content (ConvertTo-GoldenJson $selectionDocument)
#endregion Selection

#region Config layouts
# The 2.x scenarios use a frozen copy of the maester-config.json that 2.x shipped: the migration deletes
# rows from the shipped file as checks move to the native format, and the snapshot must not move with it.
$shippedTestsFolder = Join-Path $RepoRoot 'powershell/tests/fixtures/golden/shipped-2x'
& $maesterModule {
    param($Folder)
    $script:__GoldenTestFolder = $Folder
    function script:Get-MtMaesterTestFolderPath { return $script:__GoldenTestFolder }
} $shippedTestsFolder

try {
    foreach ($layout in (Get-ChildItem -Path $LayoutsRoot -Directory | Sort-Object Name)) {
        Write-Verbose "Config layout: $($layout.Name)"
        $scenarios = [System.Collections.Generic.List[object]]::new()
        foreach ($tenantId in @($null, $GoldenTenantId)) {
            $verbose = [System.Collections.Generic.List[string]]::new()
            $config = & $maesterModule {
                param($Path, $TenantId, $Log)
                $records = Get-MtMaesterConfig -Path $Path -TenantId $TenantId -Verbose 4>&1 3>$null
                foreach ($record in $records) {
                    if ($record -is [System.Management.Automation.VerboseRecord]) { $Log.Add($record.Message) } else { $record }
                }
            } $layout.FullName $tenantId $verbose

            $loaded = $verbose | Where-Object { $_ -like 'Loading Maester config from: *' } | Select-Object -First 1
            $custom = $verbose | Where-Object { $_ -like 'Custom config file found at *' } | Select-Object -First 1
            $configFile = if ($loaded) { Get-RepoRelativePath ($loaded -replace '^Loading Maester config from: ', '') } else { $null }
            # The frozen 2.x copy stands for the file 2.x shipped.
            if ($configFile -eq 'powershell/tests/fixtures/golden/shipped-2x/maester-config.json') { $configFile = 'tests/maester-config.json' }
            $customFile = if ($custom) { Get-RepoRelativePath (($custom -replace '^Custom config file found at ', '') -replace '\. Merging with main config\.$', '') } else { $null }

            $severity = [ordered]@{}
            foreach ($id in $GoldenSeverityIds) {
                $row = if ($config) { $config.TestSettingsHash[$id] } else { $null }
                $severity[$id] = if ($row) { $row.Severity } else { $null }
            }
            $globalSettings = [ordered]@{}
            if ($config -and $config.GlobalSettings) {
                foreach ($name in (Get-SortedString @($config.GlobalSettings.PSObject.Properties.Name))) {
                    $globalSettings[$name] = $config.GlobalSettings.$name
                }
            }

            $scenarios.Add([ordered]@{
                    TenantId        = $tenantId
                    ConfigFile      = $configFile
                    ConfigSource    = if ($config) { $config.ConfigSource } else { $null }
                    CustomOverlay   = $customFile
                    UsedShippedFile = $configFile -eq 'tests/maester-config.json'
                    GlobalSettings  = $globalSettings
                    Severity        = $severity
                })
        }

        # Maester 3.0: shipped defaults < maester-config.json < Custom/ < tenant file, merged (design section 7.3).
        $scenarios30 = [System.Collections.Generic.List[object]]::new()
        foreach ($tenantId in @($null, $GoldenTenantId)) {
            $result30 = & $maesterModule {
                param($Path, $TenantId, $TestsRoot, $Ids)
                $script:__GoldenTestFolder = $TestsRoot
                $config = Resolve-MtRunConfig -Path $Path -TenantId $TenantId -WarningAction SilentlyContinue
                $catalog = @{}
                foreach ($t in @(Get-MtTestCatalog)) { $catalog[$t.Id] = $t }
                $severity = [ordered]@{}
                foreach ($id in $Ids) {
                    $row = $config.TestSettingsHash[$id]
                    $severity[$id] = if ($row -and $row.Severity) { $row.Severity } elseif ($catalog.ContainsKey($id)) { $catalog[$id].Severity } else { $null }
                }
                [pscustomobject]@{ Config = $config; Severity = $severity }
            } $layout.FullName $tenantId $TestsRoot $GoldenSeverityIds
            & $maesterModule { param($Folder) $script:__GoldenTestFolder = $Folder } $shippedTestsFolder
            $globalSettings30 = [ordered]@{}
            foreach ($name in (Get-SortedString @($result30.Config.GlobalSettings.PSObject.Properties.Name))) { $globalSettings30[$name] = $result30.Config.GlobalSettings.$name }
            $scenarios30.Add([ordered]@{
                    TenantId          = $tenantId
                    ConfigSource      = $result30.Config.ConfigSource
                    GlobalSettings    = $globalSettings30
                    EffectiveSeverity = $result30.Severity
                })
        }

        $expected = [ordered]@{
            _meta     = [ordered]@{
                Description = 'Maester 2.x golden: which config file(s) Get-MtMaesterConfig picks for this folder. Regenerate with build/golden/Export-MtGoldenFixture.ps1; never hand-edit.'
                Layout      = $layout.Name
                Files       = @(Get-SortedString @(Get-ChildItem -Path $layout.FullName -Recurse -File | Where-Object Name -notin '.gitkeep', 'expected.json' | ForEach-Object { (Get-RepoRelativePath $_.FullName).Substring((Get-RepoRelativePath $layout.FullName).Length + 1) }))
                Notes       = 'The shipped file is the module''s maester-tests/maester-config.json; here Get-MtMaesterTestFolderPath is pointed at the repo tests/ folder, which the build copies there. Paths are repo-relative.'
            }
            Scenarios = $scenarios.ToArray()
            Scenarios30 = $scenarios30.ToArray()
        }
        Write-GoldenFile -Path (Join-Path $OutputPath "config-layouts/$($layout.Name)/expected.json") -Content (ConvertTo-GoldenJson $expected)
    }
} finally {
    & $maesterModule { Remove-Item -Path function:script:Get-MtMaesterTestFolderPath -ErrorAction SilentlyContinue }
}
#endregion Config layouts

Remove-Module MaesterGoldenStub -Force -ErrorAction SilentlyContinue

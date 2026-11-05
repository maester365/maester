<#
.SYNOPSIS
Writes the test catalog of the Zero Trust Assessment pack from a copy of the ZeroTrustAssessment module.

.DESCRIPTION
Reads the [ZtTest] attribute of every Test-Assessment.<id>.ps1 in the module's tests folder from the syntax tree
(nothing is run), applies the titles and ratings of the module's TestMeta.json the way the assessment does, and
writes packs/zero-trust-assessment/catalog.json: the module version it was built from and one entry per test,
with the test's Description and Remediation from its Test-Assessment.<id>.md (Microsoft's text, MIT licence), so
maester.dev can show them.

The catalog lists what the pack can report before any run: the test IDs, titles and ratings shown in the
pack's listing. Results at run time come from the assessment's report, so a test added in a newer version of
the module is still reported; rerun this script when the pack moves to a new version.

.PARAMETER SourcePath
The ZeroTrustAssessment module folder (the one that holds ZeroTrustAssessment.psd1), or a clone of
https://github.com/microsoft/zerotrustassessment. Defaults to the newest installed version of the module.

.PARAMETER OutputPath
Where to write the catalog. Defaults to packs/zero-trust-assessment/catalog.json in this repository.

.PARAMETER MappingPath
The pack's mapping of assessment tests to Maester's taxonomy: what each test is about (Product, Feature, Area,
RelatedProduct), the ATT&CK techniques its control addresses (Mitre) and the built-in Maester tests that check the
same setting (AlsoCheckedBy). The assessment has none of these, so the mapping is kept by hand in
packs/zero-trust-assessment/taxonomy.json, keyed by assessment test ID, and copied into each catalog entry. A test
the mapping does not have is written without them, with a warning: add it to the mapping.

.EXAMPLE
./build/zta/Update-MtZtaCatalog.ps1

.EXAMPLE
./build/zta/Update-MtZtaCatalog.ps1 -SourcePath ~/src/zerotrustassessment
#>
[CmdletBinding()]
param(
    [string] $SourcePath,

    [string] $OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'packs', 'zero-trust-assessment', 'catalog.json'),

    [string] $MappingPath = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'packs', 'zero-trust-assessment', 'taxonomy.json')
)

$ErrorActionPreference = 'Stop'

if (-not $SourcePath) {
    $installed = Get-Module -Name ZeroTrustAssessment -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $installed) { throw 'The ZeroTrustAssessment module is not installed. Install it, or pass -SourcePath.' }
    $SourcePath = $installed.ModuleBase
}
$manifestPath = @(
    (Join-Path $SourcePath 'ZeroTrustAssessment.psd1'),
    (Join-Path -Path $SourcePath -ChildPath 'src' -AdditionalChildPath 'powershell', 'ZeroTrustAssessment.psd1')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $manifestPath) { throw "No ZeroTrustAssessment.psd1 under $SourcePath." }
$moduleRoot = Split-Path -Parent $manifestPath
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
$testsPath = Join-Path $moduleRoot 'tests'

$mapping = @{}
if (Test-Path -LiteralPath $MappingPath) {
    $json = Get-Content -LiteralPath $MappingPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    foreach ($key in $json.Tests.Keys) { $mapping[[string]$key] = $json.Tests[$key] }
}

$meta = @{}
$metaPath = Join-Path $testsPath 'TestMeta.json'
if (Test-Path -LiteralPath $metaPath) {
    $json = Get-Content -LiteralPath $metaPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    foreach ($key in $json.Keys) { $meta[[string]$key] = $json[$key] }
}

function ConvertFrom-MtZtaAttributeValue {
    param($Ast)
    switch ($Ast.GetType().Name) {
        'StringConstantExpressionAst' { return $Ast.Value }
        'ConstantExpressionAst' { return $Ast.Value }
        'ExpandableStringExpressionAst' { return $Ast.Value }
        'ParenExpressionAst' { return ConvertFrom-MtZtaAttributeValue $Ast.Pipeline.PipelineElements[0].Expression }
        'ArrayLiteralAst' { return @($Ast.Elements | ForEach-Object { ConvertFrom-MtZtaAttributeValue $_ }) }
        'VariableExpressionAst' { return [bool]($Ast.VariablePath.UserPath -eq 'true') }
        default { return $Ast.Extent.Text }
    }
}

$tests = foreach ($file in Get-ChildItem -LiteralPath $testsPath -Filter 'Test-Assessment.*.ps1' | Sort-Object Name) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
    $attribute = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.AttributeAst] -and $node.TypeName.Name -eq 'ZtTest'
        }, $true)
    if (-not $attribute) {
        Write-Warning "$($file.Name) has no [ZtTest] attribute; skipped."
        continue
    }
    $values = @{}
    foreach ($argument in $attribute.NamedArguments) {
        $values[$argument.ArgumentName] = ConvertFrom-MtZtaAttributeValue $argument.Argument
    }
    $id = [string]$values.TestId
    # TestMeta.json is what the assessment itself shows; it wins over the attribute, as in Add-ZtTestResultDetail.
    foreach ($key in 'Title', 'Category', 'Pillar', 'RiskLevel', 'UserImpact', 'ImplementationCost', 'SfiPillar', 'TenantType', 'MinimumLicense') {
        if ($meta.ContainsKey($id) -and $meta[$id].ContainsKey($key) -and $meta[$id][$key]) { $values[$key] = $meta[$id][$key] }
    }
    # The test's own text: Test-Assessment.<id>.md up to the results placeholder, split at its remediation heading.
    $description = ''
    $remediation = ''
    $markdownPath = Join-Path $testsPath "Test-Assessment.$id.md"
    if (Test-Path -LiteralPath $markdownPath) {
        $text = (Get-Content -LiteralPath $markdownPath -Raw -Encoding utf8) -replace "`r`n", "`n"
        $text = ($text -split '<!---\s*Results\s*--->', 2)[0].Trim()
        # An instance Split: the static one would read the 2 as RegexOptions and split at every remediation heading.
        $parts = [regex]::new('(?m)^\s*(?:\*\*Remediation (?:actions?|resources)\*\*|#+\s*Remediation (?:actions?|resources))\s*$').Split($text, 2)
        $description = $parts[0].Trim()
        if ($parts.Count -gt 1) { $remediation = $parts[1].Trim() }
        # Some tests have only a placeholder ("...") where their text will go.
        if ($description -match '^\W*$') { $description = '' }
    }
    $map = $mapping[$id]
    if (-not $map) { Write-Warning "ZTA.$id ($($values.Title)) is not in $MappingPath; add it."; $map = @{} }
    [ordered]@{
        Id                 = "ZTA.$id"
        TestId             = $id
        Title              = (([string]$values.Title) -replace "''", "'" -replace '\s+', ' ').Trim()
        Pillar             = @($values.Pillar | Where-Object { $_ })
        Category           = [string]$values.Category
        Severity           = if ([string]$values.RiskLevel -in 'High', 'Medium', 'Low') { [string]$values.RiskLevel } else { $null }
        UserImpact         = [string]$values.UserImpact
        ImplementationCost = [string]$values.ImplementationCost
        Service            = @($values.Service | Where-Object { $_ })
        License            = @(@($values.CompatibleLicense) + @($values.MinimumLicense) | Where-Object { $_ } | Select-Object -Unique)
        TenantType         = @($values.TenantType | Where-Object { $_ })
        Product            = $map.Product
        RelatedProduct     = @($map.RelatedProduct | Where-Object { $_ })
        Feature            = $map.Feature
        Area               = $map.Area
        Mitre              = @($map.Mitre | Where-Object { $_ })
        AlsoCheckedBy      = @($map.AlsoCheckedBy | Where-Object { $_ })
        Description        = $description
        Remediation        = $remediation
    }
}

# The module's MIT licence: the copyright and permission notice must go with the text copied into Tests.
$licensePath = Get-ChildItem -LiteralPath $moduleRoot -File | Where-Object Name -Match '^licen[cs]e(\.txt|\.md)?$' | Select-Object -First 1
# An installed module has it beside the manifest; a clone of the repository (src/powershell) at its root.
foreach ($folder in (Split-Path -Parent $moduleRoot), (Split-Path -Parent (Split-Path -Parent $moduleRoot))) {
    if ($licensePath -or -not $folder) { break }
    $licensePath = Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue | Where-Object Name -Match '^licen[cs]e(\.txt|\.md)?$' | Select-Object -First 1
}
if (-not $licensePath) { throw "No licence file next to $manifestPath; the catalog copies the module's text and must carry its notice." }
$licenseLines = (Get-Content -LiteralPath $licensePath.FullName -Raw -Encoding utf8) -replace "`r`n", "`n" -split "`n"
$indent = ($licenseLines | Where-Object { $_.Trim() } | ForEach-Object { $_.Length - $_.TrimStart().Length } | Measure-Object -Minimum).Minimum
$license = (($licenseLines | ForEach-Object { if ($_.Length -ge $indent) { $_.Substring($indent) } else { $_.TrimStart() } }) -join "`n").Trim()

$catalog = [ordered]@{
    '$comment'   = 'Generated by build/zta/Update-MtZtaCatalog.ps1 from the ZeroTrustAssessment module (MIT licence, (c) Microsoft Corporation) and the pack''s taxonomy.json. Do not edit by hand.'
    Module       = 'ZeroTrustAssessment'
    ModuleVersion = [string]$manifest.ModuleVersion
    Source       = 'https://github.com/microsoft/zerotrustassessment'
    License      = $license
    Tests        = @($tests | Sort-Object { [int]$_.TestId })
}
$catalog | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding utf8NoBOM
Write-Information -InformationAction Continue -MessageData "Wrote $(@($tests).Count) tests from ZeroTrustAssessment $($manifest.ModuleVersion) to $OutputPath."

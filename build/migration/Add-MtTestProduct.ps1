<#
.SYNOPSIS
    One-time migration: writes the Product property into the [MaesterTest] attribute of every built-in test.

.DESCRIPTION
    Product was a reserved name until the console dashboard and the run summary needed to group tests by
    product. Each suite already says which product a test belongs to, so the value is taken from the suite's
    own structure and written into the attribute once; nothing derives it at run time.

      AD suite                 Active Directory
      AZDO.*                   Azure DevOps
      CIS.GH.*                 GitHub
      CIS.M365.<section>.*     the benchmark's section: 1 Microsoft 365, 2 Defender, 3 Purview, 4 Intune,
                               5 Entra ID, 6 Exchange Online, 7 SharePoint, 8 Teams
      CISA.MS.<baseline>.*     AAD Entra ID, EXO Exchange Online, SHAREPOINT SharePoint
      EIDSCA.*                 Entra ID
      ORCA.*                   Defender
      Maester suite            its category: Maester/Entra Entra ID, Maester/Defender Defender, ...

    A test that already has a Product is left alone. The script stops if a test matches no rule.

.PARAMETER Path
    The built-in tests folder. Defaults to ./tests.

.EXAMPLE
    ./build/migration/Add-MtTestProduct.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Path = (Join-Path $PSScriptRoot '../../tests')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../powershell/Maester.psd1') -Force

$categoryProduct = @{
    'Maester/Entra'                       = 'Entra ID'
    'Maester/Defender'                    = 'Defender'
    'Defender for Identity health issues' = 'Defender'
    'Exposure Management'                 = 'Defender'
    'Maester/Exchange'                    = 'Exchange Online'
    'Maester/Intune'                      = 'Intune'
    'Maester/Purview'                     = 'Purview'
    'Maester/Teams'                       = 'Teams'
    'Maester/Drift'                       = 'Microsoft 365'
    'AzureConfig'                         = 'Azure'
    'Azure DevOps'                        = 'Azure DevOps'
    'Copilot Studio Agent Security'       = 'Copilot Studio'
}
$cisSection = @{ '1' = 'Microsoft 365'; '2' = 'Defender'; '3' = 'Purview'; '4' = 'Intune'; '5' = 'Entra ID'; '6' = 'Exchange Online'; '7' = 'SharePoint'; '8' = 'Teams' }
$cisaBaseline = @{ 'AAD' = 'Entra ID'; 'EXO' = 'Exchange Online'; 'SHAREPOINT' = 'SharePoint' }

function Get-Product($test) {
    switch -Regex ($test.Id) {
        '^AD-' { return 'Active Directory' }
        '^AZDO\.' { return 'Azure DevOps' }
        '^CIS\.GH\.' { return 'GitHub' }
        '^CIS\.M365\.(\d+)\.' { return $cisSection[$Matches[1]] }
        '^CISA\.MS\.([A-Z]+)\.' { return $cisaBaseline[$Matches[1]] }
        '^EIDSCA\.' { return 'Entra ID' }
        '^ORCA\.' { return 'Defender' }
    }
    if ($test.Suite -eq 'AD') { return 'Active Directory' }
    $categoryProduct[[string]$test.Category]
}

$root = (Resolve-Path $Path).Path
$tests = & (Get-Module Maester) { param($root) Get-MtNativeTestInventory -Path $root -Root $root -BuiltIn } $root
$changed = 0
$counts = @{}
foreach ($test in $tests) {
    if ($test.File -match '[\\/]Custom[\\/]') { continue }
    if ($test.Product) { $counts[$test.Product]++; continue }
    $product = Get-Product $test
    if (-not $product) { throw "No product rule for $($test.Id) (suite $($test.Suite), category $($test.Category)) in $($test.File)." }
    $counts[$product]++

    $bytes = [System.IO.File]::ReadAllBytes($test.File)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [System.Text.UTF8Encoding]::new($false).GetString($bytes, $(if ($hasBom) { 3 } else { 0 }), $bytes.Length - $(if ($hasBom) { 3 } else { 0 }))
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null)
    $attribute = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AttributeAst] -and $n.TypeName.Name -in 'MaesterTest', 'MaesterTestAttribute' }, $true) | Select-Object -First 1
    $anchor = foreach ($name in 'Category', 'Severity', 'Title') {
        $attribute.NamedArguments | Where-Object { $_.ArgumentName -eq $name } | Select-Object -First 1
    }
    $anchor = @($anchor)[0]
    # Same indentation as the property the new line follows.
    $lineStart = $text.LastIndexOf("`n", $anchor.Extent.StartOffset) + 1
    $indent = $text.Substring($lineStart, $anchor.Extent.StartOffset - $lineStart)
    if ($indent.Trim()) { $indent = ' ' * $indent.Length }
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $insert = ",$newline${indent}Product = '$($product.Replace("'", "''"))'"
    $newText = $text.Insert($anchor.Extent.EndOffset, $insert)
    if ($PSCmdlet.ShouldProcess($test.File, "Add Product = '$product'")) {
        [System.IO.File]::WriteAllText($test.File, $newText, [System.Text.UTF8Encoding]::new($hasBom))
        $changed++
    }
}
$counts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { '{0,5}  {1}' -f $_.Value, $_.Key }
"$changed file(s) changed, $(@($tests).Count) tests read."

<#
.SYNOPSIS
    Migration: rewrites the [MaesterTest] attribute of every built-in test to the typed attributes of Maester 3.0.

.DESCRIPTION
    Implements section 8 of docs/proposals/maester-3.0-test-attributes.md. For every tests/**/Test.<ID>.ps1
    (tests/custom and the generated suites excluded) the script:

      - drops Category;
      - turns Preview into Lifecycle = 'Preview', and the 2.x tag Deprecated into Lifecycle = 'Deprecated';
      - writes Product as its taxonomy key (Entra ID becomes entra);
      - removes Tag: built-in tests ship without taxonomy tags, and the 2.x tags keep selecting the same
        tests through powershell/assets/Maester.LegacyTags.json;
      - merges the values of build/migration/attributes/*.json, when there are such files;
      - orders the properties: Id, Title; Product, RelatedProduct, Feature, Area, ResourceType; Severity,
        UserImpact, ImplementationCost; Mitre, Control; Service, License, Permission, TenantType, Cloud,
        Platform; Lifecycle, ReplacedBy, LongRunning, Exclusive, InstanceSource, Tag; Author, Contributor,
        HelpUrl.

    Only the attribute is rewritten, and only when it changes. The rest of the file, its encoding, byte
    order mark and line endings stay as they are. A value that is not touched keeps its text.

    The EIDSCA and ORCA tests are generated, so their files are never edited: the values go into
    build/eidsca/eidsca-test-metadata.json and build/orca/orca-test-metadata.json and both generators are
    run, which emit them. The Tags of the built-in suite.json files are removed for the same reason Tag is.

    A values file looks like this. Other keys are ignored. A null or empty value means "do not write the
    property": a value already in the attribute stays. Files are read in name order and a later file wins.

        { "Tests": [ { "Id": "MT.1012", "RelatedProduct": [], "Feature": "conditional-access",
                       "Area": "authentication", "ResourceType": "Tenant", "UserImpact": "Low",
                       "ImplementationCost": "Low", "Mitre": ["T1078.004", "T1110"] } ] }

    The script is idempotent: a second run with the same values changes nothing. It ends with one summary
    line that counts each kind of change, after validating every built-in test with the module's reader.

    It removes every Tag it finds, so it is a tool for the migration only. Once a built-in test carries a
    label of its own again, do not run it over that test.

.PARAMETER Path
    The built-in tests folder. Defaults to ./tests.

.PARAMETER AttributesPath
    The folder with the values files. Defaults to ./build/migration/attributes. It does not have to exist.

.PARAMETER SkipGenerators
    Does not run the EIDSCA and ORCA generators. Their metadata files are still updated.

.PARAMETER SkipValidation
    Does not read the tests back with the module after the rewrite.

.EXAMPLE
    ./build/migration/Convert-MtTestAttributes.ps1 -WhatIf

    Shows what would change without writing anything.

.EXAMPLE
    ./build/migration/Convert-MtTestAttributes.ps1

    Converts the built-in tests, merges the values files and regenerates the EIDSCA and ORCA tests.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'The script converts the attributes of many tests.')]
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Path = (Join-Path $PSScriptRoot '../../tests'),
    [string] $AttributesPath = (Join-Path $PSScriptRoot 'attributes'),
    [switch] $SkipGenerators,
    [switch] $SkipValidation
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$testsRoot = (Resolve-Path $Path).Path
$ignoreCase = [System.StringComparer]::OrdinalIgnoreCase

# Order of the properties in a rewritten attribute. A property that is not listed keeps its place after them.
$propertyOrder = @(
    'Id', 'Title',
    'Product', 'RelatedProduct', 'Feature', 'Area', 'ResourceType',
    'Severity', 'UserImpact', 'ImplementationCost',
    'Mitre', 'Control',
    'Service', 'License', 'Permission', 'TenantType', 'Cloud', 'Platform',
    'Lifecycle', 'ReplacedBy', 'LongRunning', 'Exclusive', 'InstanceSource', 'Tag',
    'Author', 'Contributor', 'HelpUrl'
)
$orderIndex = @{}
for ($i = 0; $i -lt $propertyOrder.Count; $i++) { $orderIndex[$propertyOrder[$i]] = $i }
# The properties a values file may set, and which of them are lists.
$valueProperties = @('RelatedProduct', 'Feature', 'Area', 'ResourceType', 'UserImpact', 'ImplementationCost', 'Mitre')
$listProperties = @('RelatedProduct', 'Mitre')
# Generated suites: folder under tests/, and the generator metadata file that takes their values.
$generatedSuites = @(
    @{ Name = 'EIDSCA'; Folder = 'eidsca'; Metadata = Join-Path $repoRoot 'build/eidsca/eidsca-test-metadata.json'; Generator = Join-Path $repoRoot 'build/eidsca/Update-EidscaTests.ps1'; Arguments = @() }
    @{ Name = 'ORCA'; Folder = 'orca'; Metadata = Join-Path $repoRoot 'build/orca/orca-test-metadata.json'; Generator = Join-Path $repoRoot 'build/orca/Update-OrcaTests.ps1'; Arguments = @('-Offline') }
)

#region Taxonomy
$taxonomy = Import-PowerShellDataFile -Path (Join-Path $repoRoot 'powershell/assets/MaesterTaxonomy.psd1')
$productKeys = [System.Collections.Generic.Dictionary[string, string]]::new($ignoreCase)
foreach ($product in $taxonomy.Products) { $productKeys[$product.Key] = $product.Key }
foreach ($product in $taxonomy.Products) { foreach ($alias in @($product.Aliases)) { if (-not $productKeys.ContainsKey($alias)) { $productKeys[$alias] = $product.Key } } }
$canonical = @{
    Feature            = @($taxonomy.Products | ForEach-Object { $_.Features.Key } | Select-Object -Unique)
    Area               = @($taxonomy.Areas.Key)
    ResourceType       = @($taxonomy.ResourceTypes.Key)
    UserImpact         = @('Low', 'Medium', 'High')
    ImplementationCost = @('Low', 'Medium', 'High')
}
#endregion Taxonomy

#region Helpers
function Format-AttributeString {
    param([string] $Value)
    "'" + $Value.Replace("'", "''") + "'"
}

function Format-AttributeValue {
    # One value as 'a', several as ('a', 'b'): the style of the built-in tests.
    param([string[]] $Value)
    if ($Value.Count -eq 1) { return Format-AttributeString $Value[0] }
    '(' + (($Value | ForEach-Object { Format-AttributeString $_ }) -join ', ') + ')'
}

function Get-AttributeArgumentValue {
    # The constant value(s) of a named attribute argument: strings, or $true/$false. A bare flag is $true.
    param([System.Management.Automation.Language.NamedAttributeArgumentAst] $Argument)
    if ($Argument.ExpressionOmitted) { return , @($true) }
    $expression = $Argument.Argument
    while ($expression -is [System.Management.Automation.Language.ParenExpressionAst]) {
        $expression = $expression.Pipeline.PipelineElements[0].Expression
    }
    $elements = if ($expression -is [System.Management.Automation.Language.ArrayLiteralAst]) { $expression.Elements } else { @($expression) }
    $values = foreach ($element in $elements) {
        if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $element.Value }
        elseif ($element -is [System.Management.Automation.Language.VariableExpressionAst] -and $element.VariablePath.UserPath -in 'true', 'false') { $element.VariablePath.UserPath -eq 'true' }
        else { throw "'$($element.Extent.Text)' is not a constant." }
    }
    , @($values)
}

function ConvertTo-ValueSet {
    # The values one test gets from a values file row: property name -> string[] (never empty).
    param([object] $Row)
    $set = [ordered]@{}
    foreach ($name in $valueProperties) {
        $property = $Row.PSObject.Properties | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $property) { continue }
        $items = @(@($property.Value) | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
        if ($items.Count -eq 0) { continue }
        if ($name -notin $listProperties -and $items.Count -ne 1) { throw "Test $($Row.Id): $name takes one value, not $($items.Count)." }
        # Registry spelling where the value is a registry value; anything else is left for the reader to judge.
        $items = @(foreach ($item in $items) {
                if ($name -eq 'RelatedProduct' -and $productKeys.ContainsKey($item)) { $productKeys[$item] }
                elseif ($canonical.ContainsKey($name) -and ($canonical[$name] | Where-Object { $_ -eq $item })) { $canonical[$name] | Where-Object { $_ -eq $item } | Select-Object -First 1 }
                else { $item }
            })
        $set[$name] = [string[]]@($items | Select-Object -Unique)
    }
    $set
}

function Read-TextFile {
    param([string] $File)
    $bytes = [System.IO.File]::ReadAllBytes($File)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $skip = if ($hasBom) { 3 } else { 0 }
    [pscustomobject]@{ Text = [System.Text.UTF8Encoding]::new($false).GetString($bytes, $skip, $bytes.Length - $skip); HasBom = $hasBom }
}

function Write-JsonFile {
    # The JSON files this script touches are all in ConvertTo-Json's own layout, LF, no byte order mark.
    param([string] $File, [object] $Value)
    $json = ((ConvertTo-Json -InputObject $Value -Depth 10) -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    [System.IO.File]::WriteAllText($File, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-FolderHash {
    param([string] $Folder)
    $table = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Folder -File) { $table[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    $table
}
#endregion Helpers

$count = [ordered]@{
    Files = 0; Changed = 0; Category = 0; Preview = 0; Deprecated = 0; Product = 0; Tag = 0; Reordered = 0; Values = 0
    Eidsca = 0; Orca = 0; Generated = 0; Suites = 0; UnknownIds = 0; Invalid = 0
}
$valueCount = [ordered]@{}
foreach ($name in $valueProperties) { $valueCount[$name] = 0 }

#region Values files
$values = [System.Collections.Generic.Dictionary[string, object]]::new($ignoreCase)
$valueFiles = @(if (Test-Path -LiteralPath $AttributesPath -PathType Container) { Get-ChildItem -LiteralPath $AttributesPath -Filter '*.json' -File | Sort-Object Name })
$overridden = 0
foreach ($file in $valueFiles) {
    $document = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    foreach ($row in @($document.Tests)) {
        if ($null -eq $row -or [string]::IsNullOrWhiteSpace($row.Id)) { continue }
        $id = ([string]$row.Id).Trim()
        $set = ConvertTo-ValueSet -Row $row
        if (-not $values.ContainsKey($id)) { $values[$id] = [ordered]@{} }
        foreach ($name in $set.Keys) {
            if ($values[$id].Contains($name) -and (($values[$id][$name] -join '|') -ne ($set[$name] -join '|'))) { $overridden++ }
            $values[$id][$name] = $set[$name]
        }
    }
}
$usedIds = [System.Collections.Generic.HashSet[string]]::new($ignoreCase)
#endregion Values files

#region Hand-written tests
$generatedFolders = @($generatedSuites | ForEach-Object { (Join-Path $testsRoot $_.Folder) + [System.IO.Path]::DirectorySeparatorChar })
$customFolder = (Join-Path $testsRoot 'custom') + [System.IO.Path]::DirectorySeparatorChar
$testFiles = @(Get-ChildItem -LiteralPath $testsRoot -Recurse -File -Filter 'Test.*.ps1' | Sort-Object FullName | Where-Object {
        $full = $_.FullName
        -not $full.StartsWith($customFolder, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not ($generatedFolders | Where-Object { $full.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })
    })

foreach ($file in $testFiles) {
    $count.Files++
    $source = Read-TextFile -File $file.FullName
    $text = $source.Text
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref] $tokens, [ref] $parseErrors)
    if ($parseErrors) { throw "$($file.FullName) does not parse: $($parseErrors[0].Message)" }
    $attributes = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AttributeAst] -and $n.TypeName.Name -in 'MaesterTest', 'MaesterTestAttribute' }, $true))
    if ($attributes.Count -ne 1) { throw "$($file.FullName) has $($attributes.Count) [MaesterTest] attributes; expected one." }
    $attribute = $attributes[0]
    if ($attribute.PositionalArguments.Count -gt 0) { throw "$($file.FullName): [MaesterTest] has positional arguments." }
    if ($tokens | Where-Object { $_.Kind -eq 'Comment' -and $_.Extent.StartOffset -ge $attribute.Extent.StartOffset -and $_.Extent.EndOffset -le $attribute.Extent.EndOffset }) {
        throw "$($file.FullName): [MaesterTest] has a comment inside it, which a rewrite would lose. Move the comment above the attribute."
    }

    # The arguments as written: name, the whole text of the argument, and its value(s).
    $arguments = [System.Collections.Generic.List[object]]::new()
    foreach ($named in $attribute.NamedArguments) {
        $arguments.Add([pscustomobject]@{ Name = $named.ArgumentName; Text = $named.Extent.Text; Value = (Get-AttributeArgumentValue -Argument $named) })
    }
    $find = { param($name) $arguments | Where-Object { $_.Name -eq $name } | Select-Object -First 1 }
    $set = {
        param($name, [string[]] $value)
        $textValue = "$name = $(Format-AttributeValue $value)"
        $existing = & $find $name
        if ($existing) {
            if (($existing.Value -join '|') -ceq ($value -join '|')) { return $false }
            $existing.Text = $textValue; $existing.Value = $value
        } else {
            $arguments.Add([pscustomobject]@{ Name = $name; Text = $textValue; Value = $value })
        }
        $true
    }
    $id = [string](& $find 'Id').Value[0]
    $changes = [System.Collections.Generic.List[string]]::new()

    $category = & $find 'Category'
    if ($category) { $null = $arguments.Remove($category); $count.Category++; $changes.Add('Category removed') }

    $preview = & $find 'Preview'
    if ($preview) {
        $null = $arguments.Remove($preview)
        if ($preview.Value[0] -eq $true -and -not (& $find 'Lifecycle')) { $null = & $set 'Lifecycle' @('Preview') }
        $count.Preview++; $changes.Add("Preview -> Lifecycle")
    }

    $tag = & $find 'Tag'
    if ($tag) {
        # Deprecated was a tag in 2.x; it is a lifecycle now.
        if ($tag.Value -contains 'Deprecated' -and -not (& $find 'Lifecycle')) {
            $null = & $set 'Lifecycle' @('Deprecated'); $count.Deprecated++; $changes.Add('Deprecated tag -> Lifecycle')
        }
        $null = $arguments.Remove($tag); $count.Tag++; $changes.Add('Tag removed')
    }

    $product = & $find 'Product'
    if ($product) {
        $name = [string]$product.Value[0]
        if (-not $productKeys.ContainsKey($name)) { throw "$($file.FullName): Product '$name' is not a key or alias in the taxonomy registry." }
        if ($name -cne $productKeys[$name]) {
            $null = & $set 'Product' @($productKeys[$name]); $count.Product++; $changes.Add("Product = '$($productKeys[$name])'")
        }
    }

    if ($values.ContainsKey($id)) {
        $null = $usedIds.Add($id)
        $merged = $false
        foreach ($name in $values[$id].Keys) {
            if (& $set $name $values[$id][$name]) { $valueCount[$name]++; $merged = $true; $changes.Add("$name set") }
        }
        if ($merged) { $count.Values++ }
    }

    $ordered = @($arguments | Sort-Object -Stable { if ($orderIndex.ContainsKey($_.Name)) { $orderIndex[$_.Name] } else { $propertyOrder.Count } })
    $oldText = $attribute.Extent.Text
    $open = $oldText.Substring(0, $oldText.IndexOf('(') + 1)
    if ($oldText.Contains("`n")) {
        $newline = if ($oldText.Contains("`r`n")) { "`r`n" } else { "`n" }
        # The indentation of the first argument and of the closing bracket, as written.
        $first = $attribute.NamedArguments[0].Extent.StartOffset
        $lineStart = $text.LastIndexOf("`n", $first) + 1
        $argumentIndent = $text.Substring($lineStart, $first - $lineStart)
        if ($argumentIndent.Trim()) { $argumentIndent = ' ' * 8 }
        $close = $attribute.Extent.EndOffset - 2
        $lineStart = $text.LastIndexOf("`n", $close) + 1
        $closeIndent = $text.Substring($lineStart, $close - $lineStart)
        if ($closeIndent.Trim()) { $closeIndent = ' ' * 4 }
        $newText = $open + $newline + (($ordered | ForEach-Object { "$argumentIndent$($_.Text)" }) -join ",$newline") + $newline + $closeIndent + ')]'
    } else {
        $newText = $open + (($ordered | ForEach-Object { $_.Text }) -join ', ') + ')]'
    }
    if ($newText -ceq $oldText) { continue }

    $count.Changed++
    if ($changes.Count -eq 0) { $count.Reordered++; $changes.Add('Properties reordered') }
    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
    if ($PSCmdlet.ShouldProcess($relative, ($changes -join '; '))) {
        $newContent = $text.Substring(0, $attribute.Extent.StartOffset) + $newText + $text.Substring($attribute.Extent.EndOffset)
        [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.UTF8Encoding]::new($source.HasBom))
    }
}
#endregion Hand-written tests

#region Generated suites
foreach ($suite in $generatedSuites) {
    $folder = Join-Path $testsRoot $suite.Folder
    if (-not (Test-Path -LiteralPath $folder)) { continue }
    $ids = @(Get-ChildItem -LiteralPath $folder -File -Filter 'Test.*.ps1' | ForEach-Object { $_.Name -replace '^Test\.', '' -replace '\.ps1$', '' })
    $metadata = Get-Content -LiteralPath $suite.Metadata -Raw | ConvertFrom-Json
    $rowsChanged = 0
    foreach ($id in $ids) {
        if (-not $values.ContainsKey($id)) { continue }
        $null = $usedIds.Add($id)
        # EIDSCA keeps a list of rows with an Id; ORCA a table keyed by ID.
        $row = if ($suite.Name -eq 'EIDSCA') { @($metadata.TestSettings) | Where-Object { $_.Id -eq $id } | Select-Object -First 1 } else { $metadata.Tests.PSObject.Properties[$id].Value }
        if (-not $row) {
            $row = [pscustomobject]@{}
            if ($suite.Name -eq 'EIDSCA') { $row | Add-Member -NotePropertyName Id -NotePropertyValue $id; $metadata.TestSettings = @($metadata.TestSettings) + $row }
            else { $metadata.Tests | Add-Member -NotePropertyName $id -NotePropertyValue $row }
        }
        $rowChanged = $false
        foreach ($name in $values[$id].Keys) {
            # The EIDSCA config upstream is the source of the severity of an EIDSCA check.
            if ($suite.Name -eq 'EIDSCA' -and $name -eq 'Severity') { continue }
            $value = if ($name -in $listProperties) { , [string[]]$values[$id][$name] } else { $values[$id][$name][0] }
            $existing = $row.PSObject.Properties[$name]
            if ($existing -and ((@($existing.Value) -join '|') -ceq (@($value) -join '|'))) { continue }
            if ($existing) { $row.$name = $value } else { $row | Add-Member -NotePropertyName $name -NotePropertyValue $value }
            $valueCount[$name]++; $rowChanged = $true
        }
        if ($rowChanged) { $rowsChanged++ }
    }
    $count[$(if ($suite.Name -eq 'EIDSCA') { 'Eidsca' } else { 'Orca' })] = $rowsChanged
    if ($rowsChanged -gt 0 -and $PSCmdlet.ShouldProcess(([System.IO.Path]::GetRelativePath($repoRoot, $suite.Metadata) -replace '\\', '/'), "Set the values of $rowsChanged test(s)")) {
        Write-JsonFile -File $suite.Metadata -Value $metadata
    }

    if (-not $SkipGenerators -and $PSCmdlet.ShouldProcess("tests/$($suite.Folder)", "Regenerate with $(Split-Path $suite.Generator -Leaf)")) {
        $before = Get-FolderHash -Folder $folder
        # A separate process: the generators set their own preferences and define many functions.
        $pwsh = (Get-Process -Id $PID).Path
        $generatorArguments = @($suite.Arguments)
        $output = & $pwsh -NoProfile -NonInteractive -File $suite.Generator @generatorArguments 2>&1
        if ($LASTEXITCODE -ne 0) { throw "$(Split-Path $suite.Generator -Leaf) failed:`n$($output | Out-String)" }
        $after = Get-FolderHash -Folder $folder
        $count.Generated += @($after.Keys | Where-Object { $before[$_] -ne $after[$_] }).Count + @($before.Keys | Where-Object { -not $after.ContainsKey($_) }).Count
    }
}
#endregion Generated suites

#region Suite manifests
foreach ($manifest in Get-ChildItem -LiteralPath $testsRoot -Recurse -File -Filter 'suite.json') {
    if ($manifest.FullName.StartsWith($customFolder, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
    $suiteManifest = Get-Content -LiteralPath $manifest.FullName -Raw | ConvertFrom-Json
    if (-not $suiteManifest.PSObject.Properties['Tags']) { continue }
    $count.Suites++
    if ($PSCmdlet.ShouldProcess(([System.IO.Path]::GetRelativePath($repoRoot, $manifest.FullName) -replace '\\', '/'), 'Remove Tags')) {
        $suiteManifest.PSObject.Properties.Remove('Tags')
        Write-JsonFile -File $manifest.FullName -Value $suiteManifest
    }
}
#endregion Suite manifests

$unknownIds = @($values.Keys | Where-Object { -not $usedIds.Contains($_) } | Sort-Object)
$count.UnknownIds = $unknownIds.Count
if ($unknownIds.Count -gt 0) { Write-Warning "These IDs in the values files are not built-in tests: $($unknownIds -join ', ')" }
if ($overridden -gt 0) { Write-Warning "$overridden value(s) are set differently in more than one values file; the last file in name order won." }

#region Validation
$problems = @()
if (-not $SkipValidation -and -not $WhatIfPreference) {
    Import-Module (Join-Path $repoRoot 'powershell/Maester.psd1') -Force -WarningAction SilentlyContinue
    $inventory = & (Get-Module Maester) { param($root) Get-MtNativeTestInventory -Path $root -Root $root -BuiltIn } $testsRoot
    $problems = @(foreach ($test in $inventory) {
            foreach ($e in $test.Errors) { "$([System.IO.Path]::GetRelativePath($repoRoot, $test.File) -replace '\\', '/'):$($e.Line): $($e.Message)" }
            foreach ($message in @(& (Get-Module Maester) { param($mitre) Get-MtAttackTechniqueProblem -Mitre $mitre } $test.Mitre)) {
                "$([System.IO.Path]::GetRelativePath($repoRoot, $test.File) -replace '\\', '/'): $message"
            }
        })
    $count.Invalid = $problems.Count
    foreach ($problem in ($problems | Select-Object -First 50)) { Write-Warning $problem }
    if ($problems.Count -gt 50) { Write-Warning "... and $($problems.Count - 50) more." }
}
#endregion Validation

$valueText = ($valueCount.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', '
'{0,6}  hand-written test file(s) read, {1} rewritten' -f $count.Files, $count.Changed
'{0,6}  Category removed' -f $count.Category
'{0,6}  Preview turned into Lifecycle' -f $count.Preview
'{0,6}  Deprecated tag turned into Lifecycle' -f $count.Deprecated
'{0,6}  Product written as a key' -f $count.Product
'{0,6}  Tag removed' -f $count.Tag
'{0,6}  attribute(s) only reordered' -f $count.Reordered
'{0,6}  test(s) with values merged from {1} values file(s) ({2})' -f $count.Values, $valueFiles.Count, $valueText
'{0,6}  EIDSCA and {1} ORCA metadata row(s) updated; {2} generated file(s) changed' -f $count.Eidsca, $count.Orca, $count.Generated
'{0,6}  suite.json file(s) with Tags removed' -f $count.Suites
"Summary: $(($count.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')$(if ($WhatIfPreference) { ' (WhatIf: nothing was written)' })"
if ($problems.Count -gt 0) { throw "$($problems.Count) problem(s) in the built-in tests after the rewrite; see the warnings above." }

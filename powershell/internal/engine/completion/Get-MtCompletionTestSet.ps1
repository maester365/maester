function Get-MtCompletionTestSet {
    <#
    .SYNOPSIS
    Returns the tests a command line is about, narrowed by the selectors on it, for Tab completion.

    .DESCRIPTION
    Which tests, as the command would find them:

    - Invoke-Maester: the built-in tests (unless -SkipBuiltIn), the native custom tests under -Path or, without
      -Path, in the Custom folder of the current folder, and the tests of the packs named with -Pack (all
      packs with -AllPacks).
    - Get-MtTest and Invoke-MtTest: the tests under -Path, else the built-in tests.

    Then the selectors on the line, with the rules of a run (Resolve-MtSelection, Test-MtSelectorMatch,
    Test-MtProductExcluded, Test-MtIdMatch): -Product, -ExcludeProduct, -Feature, -Area, -Severity, -Suite,
    -Tag, -ExcludeTag, -TestId and -ExcludeTestId (-Id for Get-MtTest). The caller leaves out the parameter
    being completed.

    Returns Tests and Narrowed (true when a selector was on the line).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $CommandName,
        [Parameter()] [AllowNull()] [hashtable] $BoundParameters = @{}
    )

    if (-not $BoundParameters) { $BoundParameters = @{} }
    $strings = {
        param($name)
        foreach ($item in @($BoundParameters[$name])) { if ($null -ne $item -and [string]$item -ne '') { [string]$item } }
    }
    $path = [string]$BoundParameters['Path']

    $tests = [System.Collections.Generic.List[object]]::new()
    if ($CommandName -eq 'Invoke-Maester') {
        if (-not $BoundParameters['SkipBuiltIn']) { $tests.AddRange([object[]](Get-MtCompletionIndex).Tests) }
        $customRoot = if ($path) { $path } else {
            # As Resolve-MtTestSource: the current folder when it is a Custom folder, else its Custom folder.
            $cwd = (Get-Location).Path
            if ((Split-Path -Path $cwd -Leaf) -ieq 'custom') { $cwd } else {
                Get-ChildItem -LiteralPath $cwd -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq 'custom' } | Select-Object -First 1 -ExpandProperty FullName
            }
        }
        if ($customRoot) { foreach ($t in @(Get-MtCompletionCustomTest -Path $customRoot)) { $tests.Add($t) } }
        $packs = @(& $strings 'Pack')
        if ($packs.Count -gt 0 -or $BoundParameters['AllPacks']) {
            foreach ($pack in @(Read-MtPackList -PackLock ([string]$BoundParameters['PackLock']) -Path $path)) {
                $named = $BoundParameters['AllPacks'] -or @($packs | Where-Object { $pack.Id -like $_ -or ($pack.Code -and $pack.Code -like $_) }).Count -gt 0
                if ($named) { foreach ($t in @($pack.Tests)) { $tests.Add($t) } }
            }
        }
    } elseif ($path) {
        foreach ($t in @(Get-MtCompletionCustomTest -Path $path)) { $tests.Add($t) }
    } else {
        $tests.AddRange([object[]](Get-MtCompletionIndex).Tests)
    }

    $idName = if ($CommandName -eq 'Invoke-Maester') { 'TestId' } else { 'Id' }
    $selectorNames = @('Product', 'ExcludeProduct', 'Feature', 'Area', 'Severity', 'Suite', 'Tag', 'ExcludeTag', $idName, 'ExcludeTestId')
    $narrowed = @($selectorNames | Where-Object { @(& $strings $_).Count -gt 0 }).Count -gt 0
    if (-not $narrowed) { return [pscustomobject]@{ Tests = $tests.ToArray(); Narrowed = $false } }

    # Resolve-MtSelection turns product aliases into keys. The matching below is that of Test-MtSelectorMatch,
    # Test-MtProductExcluded and Test-MtIdMatch, written as plain loops: they run for every test on each Tab.
    $selection = Resolve-MtSelection -RunConfig ([pscustomobject]@{ Selection = [pscustomobject]@{} }) -Product @(& $strings 'Product') -ExcludeProduct @(& $strings 'ExcludeProduct') -Feature @(& $strings 'Feature') -Area @(& $strings 'Area') -Severity @(& $strings 'Severity') -Suite @(& $strings 'Suite')
    $selectors = @(foreach ($name in 'Product', 'Feature', 'Area', 'Severity', 'Suite') {
            $patterns = @($selection.$name | Where-Object { $_ })
            if ($patterns.Count -gt 0) { [pscustomobject]@{ Name = $name; Patterns = $patterns } }
        })
    $excludeProduct = @($selection.ExcludeProduct | Where-Object { $_ })
    $tag = @(& $strings 'Tag')
    $excludeTag = @(& $strings 'ExcludeTag')
    $testId = @(& $strings $idName)
    $excludeTestId = @(& $strings 'ExcludeTestId')
    # True when one of the values matches one of the patterns.
    $any = {
        param($values, $patterns)
        foreach ($value in $values) { if ($value) { foreach ($pattern in $patterns) { if ($value -like $pattern) { return $true } } } }
        $false
    }
    $idMatch = {
        param($id, $patterns)
        foreach ($pattern in $patterns) { if ($(if ($pattern.Contains('*')) { $id -like $pattern } else { $id -eq $pattern })) { return $true } }
        $false
    }
    $kept = foreach ($t in $tests) {
        $products = @($t.Product) + @($t.RelatedProduct)
        $out = $false
        foreach ($s in $selectors) {
            $values = if ($s.Name -eq 'Product') { $products } else { @($t.($s.Name)) }
            if (-not (& $any $values $s.Patterns)) { $out = $true; break }
        }
        if ($out) { continue }
        if ($excludeProduct.Count -gt 0 -and (& $any $products $excludeProduct)) { continue }
        if ($tag.Count -gt 0 -and -not (& $any (@($t.Tags) + @($t.Id)) $tag)) { continue }
        if ($excludeTag.Count -gt 0 -and (& $any (@($t.Tags) + @($t.Id)) $excludeTag)) { continue }
        if ($testId.Count -gt 0 -and -not (& $idMatch $t.Id $testId)) { continue }
        if ($excludeTestId.Count -gt 0 -and (& $idMatch $t.Id $excludeTestId)) { continue }
        $t
    }
    [pscustomobject]@{ Tests = @($kept); Narrowed = $true }
}

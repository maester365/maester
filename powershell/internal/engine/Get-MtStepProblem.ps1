function Get-MtStepProblem {
    <#
    .SYNOPSIS
    Returns one message for each thing that is wrong with the step catalogue or with the steps that tests name.

    .DESCRIPTION
    Used by the catalog build, which fails on any message, and by the unit tests (docs/proposals/defenders-path.md,
    section 14). It returns:

    - the problems of the catalogue itself (Get-MtStepCatalog) and of the measure registry (Get-MtMeasureRegistry);
    - a step whose Measure names a key the registry does not have, and a registry entry whose reader function the
      module does not have;
    - a test whose Step names a step the catalogue does not have;
    - with -Coverage, when -Test is every built-in test: a step that no test names and that has no Measure but has
      no Unchecked reason, and a step that a test names but still has one;
    - too many sources that cite a maintainer instead of Microsoft Learn (more than one in ten).

    The build checks a test folder that may hold only some of the tests (a fixture, in the unit tests), so it leaves
    out -Coverage; the unit tests pass it with the full set.

    A pack's tests name steps in its taxonomy.json (packs/<name>/taxonomy.json, Tests.<id>.Step), which -PackRoot
    reads. Each message starts with the path of a file and names the step or the test.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The built-in tests (Get-MtNativeTestInventory).
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Test,

        # The folder that holds the packs that ship with Maester.
        [Parameter()] [string] $PackRoot,

        # The catalogue to check. Defaults to the module's.
        [Parameter()] [object] $Catalog = (Get-MtStepCatalog),

        # The measure registry the catalogue's Measure keys refer to. Defaults to the module's.
        [Parameter()] [object] $Registry = (Get-MtMeasureRegistry),

        # -Test is every built-in test: check that each step is named by a test or says in Unchecked why not.
        [Parameter()] [switch] $Coverage
    )

    $Catalog.Problems
    $Registry.Problems
    foreach ($measure in $Registry.Measures.Values) {
        if (-not (Get-Command -Name $measure.Function -CommandType Function -ErrorAction SilentlyContinue)) {
            "$([System.IO.Path]::GetFileName($Registry.Path)) ($($measure.Key)): the reader function $($measure.Function) does not exist."
        }
    }
    foreach ($step in $Catalog.Steps.Values) {
        if ($step.Measure -and -not $Registry.Measures.ContainsKey($step.Measure.Key)) {
            "$($step.File) ($($step.Id)): Measure names '$($step.Measure.Key)', which is not in the measure registry."
        }
    }

    # Which tests name each step.
    $namedBy = @{}
    $add = { param($step, $by) if (-not $namedBy.ContainsKey($step)) { $namedBy[$step] = [System.Collections.Generic.List[string]]::new() }; $namedBy[$step].Add($by) }
    foreach ($t in $Test) {
        if (-not $t.Id) { continue }
        foreach ($step in @($t.PSObject.Properties['Step'] | ForEach-Object { $_.Value } | Where-Object { $_ })) {
            if ($Catalog.Steps.ContainsKey($step)) { & $add $step $t.Id }
            else { "$($t.File): the test $($t.Id) names the step '$step', which is not in the step catalogue." }
        }
    }
    if ($PackRoot -and (Test-Path -LiteralPath $PackRoot -PathType Container)) {
        foreach ($file in Get-ChildItem -LiteralPath $PackRoot -Filter 'taxonomy.json' -Recurse -File -Depth 1) {
            try { $taxonomy = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop } catch { continue }
            if ($taxonomy -isnot [System.Collections.IDictionary] -or $taxonomy['Tests'] -isnot [System.Collections.IDictionary]) { continue }
            foreach ($id in $taxonomy['Tests'].Keys) {
                $entry = $taxonomy['Tests'][$id]
                if ($entry -isnot [System.Collections.IDictionary] -or -not $entry.Contains('Step')) { continue }
                foreach ($step in @($entry['Step'] | Where-Object { $_ })) {
                    if ($Catalog.Steps.ContainsKey([string]$step)) { & $add ([string]$step) "$($file.Directory.Name):$id" }
                    else { "$($file.FullName): the test $id names the step '$step', which is not in the step catalogue." }
                }
            }
        }
    }

    $checked = if ($Coverage) { @($Catalog.Steps.Values) } else { @() }
    foreach ($step in $checked) {
        $where = "$($step.File) ($($step.Id))"
        if ($namedBy.ContainsKey($step.Id) -and $step.Unchecked) {
            "${where}: $($namedBy[$step.Id] -join ', ') verify the step, so it must not have Unchecked."
        } elseif (-not $namedBy.ContainsKey($step.Id) -and -not $step.Measure -and -not $step.Unchecked) {
            "${where}: no test names the step and it has no Measure. Name it in the Step attribute of the tests that verify it, give it a Measure, or say why neither can in Unchecked."
        }
    }

    $sources = @($Catalog.Steps.Values | ForEach-Object { $_.Sources })
    $maintainerOnly = @($sources | Where-Object { $_.Maintainer -and -not $_.Url })
    if ($sources.Count -ge 10 -and $maintainerOnly.Count * 10 -gt $sources.Count) {
        "$($Catalog.Path): $($maintainerOnly.Count) of $($sources.Count) sources cite a maintainer instead of Microsoft Learn. Keep it to one in ten."
    }
}

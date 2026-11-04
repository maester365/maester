function Get-MtCompletionIndex {
    <#
    .SYNOPSIS
    Returns what Tab completion knows about the built-in tests and suites. Cached for the session.

    .DESCRIPTION
    Tests: the built-in tests, as ConvertTo-MtCompletionTest keeps them. Suites: suite ID to display name, from
    each suite.json (CISA to CISA SCuBA baselines).

    The first Tab must be quick. When the session has the catalogue already (Get-MtTestCatalog ran), its rows are
    used. Otherwise the built module's Maester.TestCatalog.json is read directly: about 50 ms, against about half
    a second for Get-MtTestCatalog, which prepares every row for a run. A source checkout has no catalogue file
    and scans tests/ once (Get-MtTestCatalog).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if ($script:__MtCompletionIndex) { return $script:__MtCompletionIndex }
    $catalogFile = Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'Maester.TestCatalog.json'
    $catalog = if (Test-Path -LiteralPath $catalogFile -PathType Leaf) { Get-Content -LiteralPath $catalogFile -Raw | ConvertFrom-Json } else { $null }
    $tests = if ($null -ne $script:__MtTestCatalog) { $script:__MtTestCatalog } elseif ($catalog) { @($catalog.Tests) } else { @(Get-MtTestCatalog) }

    $suites = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $manifests = if ($catalog -and $catalog.Suites) {
        foreach ($p in $catalog.Suites.PSObject.Properties) { $p.Value }
    } else {
        $root = Get-MtMaesterTestFolderPath
        if (Test-Path -LiteralPath $root) {
            foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'suite.json' -ErrorAction SilentlyContinue) {
                try { Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json } catch { Write-Debug "Skipped $($file.FullName): $($_.Exception.Message)" }
            }
        }
    }
    foreach ($m in $manifests) { if ($m.Id -and -not $suites.ContainsKey([string]$m.Id)) { $suites[[string]$m.Id] = [string]$m.Name } }

    $script:__MtCompletionIndex = [pscustomobject]@{
        Tests  = @(ConvertTo-MtCompletionTest -Test @($tests) -Source BuiltIn)
        Suites = $suites
    }
    $script:__MtCompletionIndex
}

function Get-MtCompletionCustomTest {
    <#
    .SYNOPSIS
    Returns the native custom tests under a folder or file, for Tab completion. Cached until the files change.

    .DESCRIPTION
    Finds Test.*.ps1 files as a run does (Get-MtCustomTestFile, three folder levels deep) and reads them
    statically (Get-MtNativeTestInventory), so no test code runs. Files under the built-in tests folder are
    left out, except its Custom folder. Pester-format tests are not read: their tags and IDs are known only
    after Pester discovery, which runs their code.

    The cache is kept per folder and read again when the number of files or the newest write time changes.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [object[]])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }
    $root = (Resolve-Path -LiteralPath $Path).Path
    $builtInRoot = Get-MtMaesterTestFolderPath
    $builtInPrefix = if (Test-Path -LiteralPath $builtInRoot) { (Resolve-Path -LiteralPath $builtInRoot).Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar } else { $null }
    $files = @(Get-MtCustomTestFile -Root $root -Format Native | Where-Object {
            -not $builtInPrefix -or -not $_.StartsWith($builtInPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
            $_.StartsWith($builtInPrefix + 'custom' + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
        })
    if ($files.Count -eq 0) { return }

    $newest = ($files | ForEach-Object { [System.IO.File]::GetLastWriteTimeUtc($_).Ticks } | Measure-Object -Maximum).Maximum
    $stamp = "$($files.Count):$newest"
    if (-not $script:__MtCompletionCustomTests) { $script:__MtCompletionCustomTests = @{} }
    $cached = $script:__MtCompletionCustomTests[$root]
    if ($cached -and $cached.Stamp -eq $stamp) { return $cached.Tests }

    $suiteRoot = if (Test-Path -LiteralPath $root -PathType Leaf) { Split-Path -Path $root -Parent } else { $root }
    $inventory = @(Get-MtNativeTestInventory -Path $files -Root $suiteRoot -FrameworkPath $suiteRoot -WarningAction SilentlyContinue)
    $tests = @(ConvertTo-MtCompletionTest -Test $inventory -Source Custom)
    $script:__MtCompletionCustomTests[$root] = @{ Stamp = $stamp; Tests = $tests }
    $tests
}

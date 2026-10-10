<#
.SYNOPSIS
    Sets FunctionsToExport in powershell/Maester.psd1 to the functions in powershell/public.

.DESCRIPTION
    Check functions migrated to native tests live in tests/ (or powershell/internal/checks for shared
    helpers) and are no longer exported (Maester 3.0 design, section 12). The build generates the same
    list; this keeps the source manifest in step.
#>
[CmdletBinding()]
param()

$repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$manifest = Join-Path $repoRoot 'powershell/Maester.psd1'
$names = @(Get-ChildItem -Path (Join-Path $repoRoot 'powershell/public') -Recurse -File -Filter '*.ps1' | ForEach-Object { $_.BaseName } | Sort-Object -Unique)
$text = [System.IO.File]::ReadAllText($manifest)
$list = ($names | ForEach-Object { "        '$_'" }) -join ",`n"
$updated = [regex]::Replace($text, '(?s)    FunctionsToExport    = @\(.*?\n    \)', "    FunctionsToExport    = @(`n$list`n    )")
[System.IO.File]::WriteAllText($manifest, $updated, [System.Text.UTF8Encoding]::new($false))
Write-Information "FunctionsToExport: $($names.Count) functions." -InformationAction Continue

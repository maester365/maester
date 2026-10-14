<#
.SYNOPSIS
    Removes the rows of tests/maester-config.json for checks that are now native tests.

.DESCRIPTION
    A native test carries its severity in its [MaesterTest] attribute, so its row in the shipped config
    is no longer needed (Maester 3.0 design, section 7.4). Run after converting checks.
#>
[CmdletBinding()]
param()

$repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$configPath = Join-Path $repoRoot 'tests/maester-config.json'
$nativeIds = @(Get-ChildItem -Path (Join-Path $repoRoot 'tests') -Recurse -File -Filter 'Test.*.ps1' |
        Where-Object { $_.FullName -notmatch '[\\/]Custom[\\/]' } |
        ForEach-Object { $_.Name -replace '^Test\.', '' -replace '\.ps1$', '' })
$json = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$before = @($json.TestSettings).Count
$json.TestSettings = @($json.TestSettings | Where-Object { $_.Id -notin $nativeIds })
$bom = [System.IO.File]::ReadAllBytes($configPath)[0] -eq 0xEF
[System.IO.File]::WriteAllText($configPath, (($json | ConvertTo-Json -Depth 10) -replace "`r`n", "`n") + "`n", [System.Text.UTF8Encoding]::new($bom))
Write-Information "Removed $($before - @($json.TestSettings).Count) row(s); $(@($json.TestSettings).Count) remain." -InformationAction Continue

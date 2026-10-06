<#
.SYNOPSIS
    Runs Maester in a session where Pester cannot be found and checks that native tests still run.

.DESCRIPTION
    Pester is not a dependency of Maester 3.0 (design section 8). Run it where Pester is not installed
    (CI deletes it from the runner first). It imports Maester from source, runs the built-in tests
    offline and a Pester-format custom test, and fails when:
    - Pester was loaded,
    - no native test produced a row,
    - the Pester-format test is not reported as an Error row with reason PesterNotAvailable.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
# PowerShell adds the user and shared module folders back when a runspace opens, so a PSModulePath
# override is not enough: Pester must not be installed at all.
if (Get-Module -ListAvailable -Name Pester) { throw "Pester is installed: $((Get-Module -ListAvailable -Name Pester).ModuleBase -join ', ')" }

$work = Join-Path ([System.IO.Path]::GetTempPath()) "maester-nopester-$([guid]::NewGuid().ToString('n'))"
$null = New-Item -ItemType Directory -Path $work
"Describe 'Custom' { It 'CONTOSO.1: Pester-format test' { `$true | Should -BeTrue } }" | Set-Content (Join-Path $work 'Custom.Tests.ps1')
$out = Join-Path $work 'result.json'

Import-Module (Join-Path $repoRoot 'powershell/Maester.psd1') -WarningAction SilentlyContinue
$null = Invoke-Maester -Path $work -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputJsonFile $out -WarningAction SilentlyContinue

if (Get-Module -Name Pester) { throw 'Pester was loaded.' }
$result = Get-Content $out -Raw | ConvertFrom-Json
$native = @($result.Tests | Where-Object Format -EQ 'Native')
$pester = @($result.Tests | Where-Object Id -EQ 'CONTOSO.1')
Write-Host "Rows: $($result.Tests.Count); native: $($native.Count)"
if ($native.Count -eq 0) { throw 'No native test produced a row.' }
if ($pester.Count -ne 1 -or $pester[0].Result -ne 'Error' -or $pester[0].ReasonCode -ne 'PesterNotAvailable') {
    throw "The Pester-format test was not reported as PesterNotAvailable: $($pester | ConvertTo-Json -Depth 3 -Compress)"
}
Remove-Item -Recurse -Force $work
Write-Host 'Maester runs without Pester.'

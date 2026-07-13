<#
.SYNOPSIS
    Regression check: empty DLP test results must not leak PowerShell function source into reports.

.DESCRIPTION
    Imports a built Maester module (consolidated ./module by default), mocks the DLP
    data path so Test-MtCisaDlpPii fails with an empty rule set, and asserts that the
    result detail markdown does not contain function definitions (the #1924 failure mode).

    Throws a terminating error on failure so it can be used as a CI gate after
    Build-MaesterModule.ps1.

.PARAMETER ModulePath
    Path to the built module directory. Defaults to ../module relative to this script.

.EXAMPLE
    ./build/Build-MaesterModule.ps1
    ./build/Test-MaesterResultDetailRegression.ps1
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'CI console script that reports progress to the workflow log.')]
[CmdletBinding()]
param (
    [Parameter()]
    [string] $ModulePath = "$PSScriptRoot/../module"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModulePath = (Resolve-Path -LiteralPath $ModulePath).Path
$ManifestPath = Join-Path $ModulePath 'Maester.psd1'
if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Module manifest not found at '$ManifestPath'. Run Build-MaesterModule.ps1 first."
}

Write-Host "── Result-detail regression against $ModulePath" -ForegroundColor Cyan

Remove-Module Maester -Force -ErrorAction SilentlyContinue
$ImportedModules = @(Import-Module $ManifestPath -Force -PassThru -ErrorAction Stop)
$ImportedModule = $ImportedModules | Where-Object { $_.Name -eq 'Maester' } | Select-Object -First 1
if (-not $ImportedModule) {
    throw 'Import-Module did not return the Maester module object.'
}

$ReproRoot = Join-Path ([System.IO.Path]::GetTempPath()) "maester-result-detail-regression-$([guid]::NewGuid())"
$ReproTests = Join-Path $ReproRoot 'tests'
$ReproOutput = Join-Path $ReproRoot 'output'
$null = New-Item -Path $ReproTests -ItemType Directory -Force

# Mocks leave Get-MtExo returning empty collections so Test-MtCisaDlpPii takes the
# empty-rules path (the path that previously leaked function source via unset $result).
$ReproTestContent = @'
Describe 'Result detail scope regression' {
    BeforeAll {
        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'Plan' }
        Mock -ModuleName Maester Get-MtExo { return @() }
    }

    It 'CISA.MS.EXO.8.2: empty DLP result does not contain function definitions' {
        Test-MtCisaDlpPii | Should -BeFalse
    }
}
'@

$ReproTestPath = Join-Path $ReproTests 'ResultDetailRegression.Tests.ps1'
$Utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($ReproTestPath, $ReproTestContent, $Utf8Bom)

try {
    $MaesterResult = Invoke-Maester `
        -Path $ReproTests `
        -OutputFolder $ReproOutput `
        -OutputFolderFileName 'ResultDetailRegression' `
        -SkipGraphConnect `
        -SkipVersionCheck `
        -NonInteractive `
        -NoLogo `
        -PassThru

    if (-not $MaesterResult -or -not $MaesterResult.Tests -or $MaesterResult.Tests.Count -lt 1) {
        throw 'Invoke-Maester did not return any test results for the regression suite.'
    }

    $Detail = $MaesterResult.Tests[0].ResultDetail
    $ResultDetail = [string] $Detail.TestResult
    $Description = [string] $Detail.TestDescription

    if ($ResultDetail -match 'Add-MtTestResultDetail\s+-Description' -or $ResultDetail -match '\.SYNOPSIS') {
        throw "Built module leaked a PowerShell function definition into TestResult. Detail was: $ResultDetail"
    }

    if ($ResultDetail -notmatch 'Your tenant does not have.*Data Loss Prevention Policies') {
        throw "Built module returned unexpected DLP result detail (expected empty-policy failure message). Detail was: $ResultDetail"
    }

    # Consolidated modules must not treat Maester.psm1 as a companion .md template (#1924).
    if ($Description -match 'Initialize Module Configuration' -or $Description -match '\.DISCLAIMER') {
        throw "Built module loaded module source as TestDescription (PSCommandPath/.psm1 markdown bug). Description length: $($Description.Length)"
    }

    if ($Description.Length -gt 20000) {
        throw "Built module TestDescription is unexpectedly large ($($Description.Length) chars); possible module-source leak."
    }

    Write-Host '   Verified: empty DLP result detail has no function definitions' -ForegroundColor Green
    Write-Host '   Verified: TestDescription is not module source' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $ReproRoot -Recurse -Force -ErrorAction SilentlyContinue
    $ImportedModules | Remove-Module -Force -ErrorAction SilentlyContinue
}

Write-Host '── Result-detail regression passed' -ForegroundColor Green

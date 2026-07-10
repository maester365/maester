<#
.SYNOPSIS
    Validates the scope-safe Maester package that is published to users.

.DESCRIPTION
    Confirms the source-layout package is complete, imports correctly, exposes command
    help, and does not leak PowerShell function definitions into test result details.

.PARAMETER ModulePath
    Path to the packaged Maester module. Defaults to ../publish/Maester relative to this script.

.PARAMETER ExpectedVersion
    Optional version the package manifest must declare. A prerelease suffix is ignored
    when comparing against ModuleVersion.

.PARAMETER MinimumCommandCount
    Minimum number of commands the package must export. Defaults to 200.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'CI validation script that reports progress to the workflow log.')]
[CmdletBinding()]
param (
    [Parameter()]
    [string] $ModulePath = "$PSScriptRoot/../publish/Maester",

    [Parameter()]
    [string] $ExpectedVersion,

    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int] $MinimumCommandCount = 200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModulePath = (Resolve-Path -LiteralPath $ModulePath).Path
Write-Host "── Validating packaged module at $ModulePath" -ForegroundColor Cyan

$ExpectedItems = @(
    'Maester.psd1'
    'Maester.psm1'
    'Maester.Format.ps1xml'
    'assets'
    'internal'
    'public'
    'maester-tests'
    'maester-tests/Custom'
)

foreach ($Item in $ExpectedItems) {
    if (-not (Test-Path -LiteralPath (Join-Path $ModulePath $Item))) {
        throw "Package output is missing expected item: $Item"
    }
}
Write-Host "   Verified: $($ExpectedItems.Count) expected files and directories present"

$ManifestPath = Join-Path $ModulePath 'Maester.psd1'
$Manifest = Import-PowerShellDataFile -Path $ManifestPath

if ($ExpectedVersion) {
    $ExpectedBaseVersion = ($ExpectedVersion -split '-')[0]
    if ($Manifest.ModuleVersion -ne $ExpectedBaseVersion) {
        throw "Manifest ModuleVersion '$($Manifest.ModuleVersion)' does not match expected version '$ExpectedBaseVersion' (from '$ExpectedVersion')."
    }
    Write-Host "   Verified: ModuleVersion $($Manifest.ModuleVersion) matches expected version"
}

Remove-Module Maester -Force -ErrorAction SilentlyContinue
$ImportedModules = @(Import-Module $ManifestPath -Force -PassThru -ErrorAction Stop)
$ImportedModule = $ImportedModules | Where-Object { $_.Name -eq 'Maester' } | Select-Object -First 1
if (-not $ImportedModule) {
    throw 'Import-Module did not return the Maester module object.'
}

$CommandCount = $ImportedModule.ExportedCommands.Count
if ($CommandCount -lt $MinimumCommandCount) {
    throw "Packaged module exports $CommandCount commands; expected at least $MinimumCommandCount."
}
Write-Host "   Verified: module imports and exports $CommandCount commands"

$SampleFunctions = @('Invoke-Maester', 'Connect-Maester', 'Get-MtRole', 'Add-MtTestResultDetail')
foreach ($FunctionName in $SampleFunctions) {
    $Help = Get-Help -Name $FunctionName -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($Help.Synopsis) -or $Help.Synopsis.TrimStart().StartsWith($FunctionName)) {
        throw "Comment-based help is missing or broken for $FunctionName (synopsis: '$($Help.Synopsis)')."
    }
}
Write-Host "   Verified: comment-based help intact for $($SampleFunctions.Count) sample functions"

$ReproRoot = Join-Path ([System.IO.Path]::GetTempPath()) "maester-package-validation-$([guid]::NewGuid())"
$ReproTests = Join-Path $ReproRoot 'tests'
$ReproOutput = Join-Path $ReproRoot 'output'
$null = New-Item -Path $ReproTests -ItemType Directory -Force

$ReproTestContent = @'
Describe 'Packaged Maester result details' {
    BeforeAll {
        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Get-MtLicenseInformation { return 'Plan' }
        Mock -ModuleName Maester Get-MtExo { return @() }
    }

    It 'CISA.MS.EXO.8.2: keeps an empty DLP result free of function definitions' {
        Test-MtCisaDlpPii | Should -BeFalse
    }
}
'@

$ReproTestPath = Join-Path $ReproTests 'PackageResultDetails.Tests.ps1'
$Utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($ReproTestPath, $ReproTestContent, $Utf8Bom)

try {
    $MaesterResult = Invoke-Maester `
        -Path $ReproTests `
        -OutputFolder $ReproOutput `
        -OutputFolderFileName 'PackageResultDetails' `
        -SkipGraphConnect `
        -SkipVersionCheck `
        -NonInteractive `
        -NoLogo `
        -PassThru

    $ResultDetail = [string] $MaesterResult.Tests[0].ResultDetail.TestResult
    if ($ResultDetail -match 'Add-MtTestResultDetail\s+-Description' -or $ResultDetail -match '\.SYNOPSIS') {
        throw 'Packaged module leaked a PowerShell function definition into TestResult.'
    }
    if ($ResultDetail -notmatch 'Your tenant does not have.*Data Loss Prevention Policies') {
        throw "Packaged module returned an unexpected DLP result detail: '$ResultDetail'"
    }
    Write-Host '   Verified: report result details do not contain PowerShell function definitions'
} finally {
    Remove-Item -LiteralPath $ReproRoot -Recurse -Force -ErrorAction SilentlyContinue
    $ImportedModules | Remove-Module -Force -ErrorAction SilentlyContinue
}

Write-Host '── Packaged module validation passed' -ForegroundColor Green

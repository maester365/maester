<#
.SYNOPSIS
    Builds, validates, and imports the local Maester module.

.DESCRIPTION
    Creates the publishable module under ./module, validates the build output,
    unloads any currently loaded Maester module, and imports the local build into
    the caller's global session so it remains available after this script exits.

.EXAMPLE
    ./build/Build-LocalMaester.ps1

    Builds and imports the local Maester module. Invoke-Maester can then be run
    against ./module/maester-tests.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Developer helper that reports the imported module path.')]
[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$BuildScript = Join-Path $PSScriptRoot 'Build-MaesterModule.ps1'
$ValidationScript = Join-Path $PSScriptRoot 'Test-MaesterModuleOutput.ps1'
$ModulePath = Join-Path $PSScriptRoot '../module'
$ModuleManifestPath = Join-Path $ModulePath 'Maester.psd1'
$ProgressActivity = 'Preparing local Maester module'

try {
    Write-Progress -Activity $ProgressActivity -Status 'Building module' -PercentComplete 10

    Get-Module -Name Maester -All | Remove-Module -Force -ErrorAction SilentlyContinue
    & $BuildScript 1>$null 3>$null 4>$null 5>$null 6>$null

    Write-Progress -Activity $ProgressActivity -Status 'Validating build' -PercentComplete 70
    & $ValidationScript -ModulePath $ModulePath 1>$null 3>$null 4>$null 5>$null 6>$null

    Write-Progress -Activity $ProgressActivity -Status 'Loading local module' -PercentComplete 90
    $ImportedModules = @(
        Import-Module $ModuleManifestPath -Force -Global -PassThru -ErrorAction Stop `
            3>$null 4>$null 5>$null 6>$null
    )
    $ImportedModule = $ImportedModules |
        Where-Object { $_.Name -eq 'Maester' } |
        Select-Object -First 1

    if (-not $ImportedModule) {
        throw 'Import-Module did not return the locally built Maester module.'
    }

    $ExpectedModuleBase = (Resolve-Path -LiteralPath $ModulePath).Path
    if ($ImportedModule.ModuleBase -ne $ExpectedModuleBase) {
        throw "Expected to import Maester from '$ExpectedModuleBase', but imported it from '$($ImportedModule.ModuleBase)'."
    }
} finally {
    Write-Progress -Activity $ProgressActivity -Completed
}

$ReadyEmoji = [char]::ConvertFromUtf32(0x1F525)
Write-Host "$ReadyEmoji Local Maester built and loaded: $($ImportedModule.ModuleBase)" -ForegroundColor Green

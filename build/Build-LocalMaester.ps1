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

Get-Module -Name Maester -All | Remove-Module -Force -ErrorAction SilentlyContinue

& $BuildScript
& $ValidationScript -ModulePath $ModulePath

$ImportedModules = @(Import-Module $ModuleManifestPath -Force -Global -PassThru -ErrorAction Stop)
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

Write-Host ''
Write-Host 'Local Maester module ready' -ForegroundColor Green
Write-Host "   Module: $($ImportedModule.ModuleBase)"
Write-Host "   Tests:  $(Join-Path $ImportedModule.ModuleBase 'maester-tests')"
Write-Host ''

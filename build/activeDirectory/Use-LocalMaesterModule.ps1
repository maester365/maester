<#
.SYNOPSIS
    Loads the local workspace Maester module for AD test sessions.

.DESCRIPTION
    Removes any already-loaded Maester modules and force-loads the module from
    this repository (powershell/Maester.psd1). This avoids parameter drift when
    an installed module version is auto-loaded from PSModulePath.

.PARAMETER Quiet
    Suppress informational host output.

.EXAMPLE
    .\build\activeDirectory\Use-LocalMaesterModule.ps1

    Loads the local workspace module and verifies Connect-Maester supports
    -ActiveDirectoryServer.

.EXAMPLE
    .\build\activeDirectory\Use-LocalMaesterModule.ps1 -Quiet

    Loads the local workspace module silently.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$localManifest = Join-Path $repoRoot 'powershell\Maester.psd1'

if (-not (Test-Path -LiteralPath $localManifest -PathType Leaf)) {
    throw "Local module manifest was not found at '$localManifest'."
}

Get-Module -Name Maester -All | Remove-Module -Force -ErrorAction SilentlyContinue
$imported = Import-Module -Name $localManifest -Force -PassThru -Global

$command = Get-Command -Name Connect-Maester -Module Maester -ErrorAction Stop
$hasAdServerParam = $command.Parameters.ContainsKey('ActiveDirectoryServer')

if (-not $hasAdServerParam) {
    throw 'Connect-Maester was loaded but does not expose ActiveDirectoryServer. Ensure the workspace module is up to date.'
}

if (-not $Quiet.IsPresent) {
    Write-Host "Loaded Maester module from: $($imported.Path)" -ForegroundColor Green
    Write-Host "Connect-Maester supports -ActiveDirectoryServer: $hasAdServerParam" -ForegroundColor Green
}

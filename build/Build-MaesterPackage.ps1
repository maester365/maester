<#
.SYNOPSIS
    Builds the scope-safe Maester package that is published to users.

.DESCRIPTION
    Copies the PowerShell module source tree without consolidating function files, then
    adds the bundled Maester test suites under maester-tests. Preserving the individual
    function files also preserves their PowerShell script-scope boundaries.

    The source trees are never modified. The output directory is cleaned and recreated
    on every run.

.PARAMETER SourceRoot
    Path to the PowerShell module source directory. Defaults to ../powershell relative
    to this script.

.PARAMETER TestsRoot
    Path to the bundled test suites. Defaults to ../tests relative to this script.

.PARAMETER OutputRoot
    Path to the package directory. Defaults to ../publish/Maester relative to this script.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'CI packaging script that reports progress to the workflow log.')]
[CmdletBinding()]
param (
    [Parameter()]
    [string] $SourceRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../powershell").Path,

    [Parameter()]
    [string] $TestsRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../tests").Path,

    [Parameter()]
    [string] $OutputRoot = "$PSScriptRoot/../publish/Maester"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$TestsRoot = (Resolve-Path -LiteralPath $TestsRoot).Path

$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$ResolvedOutput = [System.IO.Path]::GetFullPath($OutputRoot).TrimEnd('\', '/')
$DriveRoot = [System.IO.Path]::GetPathRoot($ResolvedOutput).TrimEnd('\', '/')
$ProtectedPaths = @($DriveRoot, $RepoRoot, $SourceRoot, $TestsRoot) |
    ForEach-Object { $_.TrimEnd('\', '/') }

if ($ResolvedOutput -in $ProtectedPaths) {
    throw "Refusing to use protected path '$ResolvedOutput' as OutputRoot."
}

$RepoPath = $RepoRoot.TrimEnd('\', '/')
if (-not $ResolvedOutput.StartsWith($RepoPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use OutputRoot '$OutputRoot' because it is outside the repository root '$RepoRoot'."
}

Write-Host '── Preparing scope-safe Maester package' -ForegroundColor Cyan

if (Test-Path -LiteralPath $ResolvedOutput) {
    Remove-Item -LiteralPath $ResolvedOutput -Recurse -Force
}
$null = New-Item -Path $ResolvedOutput -ItemType Directory -Force

$ExcludedSourceItems = @('.DS_Store', 'maester-tests', 'test-results')
$SourceItems = Get-ChildItem -LiteralPath $SourceRoot -Force |
    Where-Object { $_.Name -notin $ExcludedSourceItems }

foreach ($Item in $SourceItems) {
    Copy-Item -LiteralPath $Item.FullName -Destination $ResolvedOutput -Recurse -Force
}

$BundledTestsPath = Join-Path $ResolvedOutput 'maester-tests'
$null = New-Item -Path $BundledTestsPath -ItemType Directory -Force
Get-ChildItem -LiteralPath $TestsRoot -Force |
    Where-Object { $_.Name -ne '.DS_Store' } |
    Copy-Item -Destination $BundledTestsPath -Recurse -Force

Write-Host "   Module source: $($SourceItems.Count) top-level items"
Write-Host "   Bundled tests: $BundledTestsPath"
Write-Host "── Package complete: $ResolvedOutput" -ForegroundColor Green

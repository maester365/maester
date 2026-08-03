<#
.SYNOPSIS
    Refreshes the cached public suffix list used by Get-MtRegistrableDomain.

.DESCRIPTION
    Downloads the current public suffix list from publicsuffix.org and writes it
    to powershell/assets/public_domain_suffix_list.dat using UTF-8 without BOM.

    The script is idempotent: if the downloaded content matches the current
    checked-in file, it reports "No changes detected" and leaves the file
    untouched.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $SourceUrl = 'https://publicsuffix.org/list/public_suffix_list.dat',

    [Parameter()]
    [string] $OutputPath = (Join-Path $PSScriptRoot '../powershell/assets/public_domain_suffix_list.dat')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath

if (-not (Test-Path -LiteralPath $outputDirectory)) {
    throw "Output directory does not exist: $outputDirectory"
}

Write-Host "Downloading public suffix list from $SourceUrl"
$response = Invoke-WebRequest -Uri $SourceUrl -Headers @{ 'User-Agent' = 'Maester Public Suffix List Updater' }
$downloadedContent = ($response.Content -replace "`r`n", "`n")

if ([string]::IsNullOrWhiteSpace($downloadedContent)) {
    throw "Downloaded public suffix list is empty: $SourceUrl"
}

$currentContent = $null
if (Test-Path -LiteralPath $resolvedOutputPath) {
    $currentContent = ([System.IO.File]::ReadAllText($resolvedOutputPath)) -replace "`r`n", "`n"
}

if ($currentContent -eq $downloadedContent) {
    Write-Host "No changes detected in $resolvedOutputPath"
    return
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($resolvedOutputPath, $downloadedContent, $utf8NoBom)

Write-Host "Updated public suffix list at $resolvedOutputPath"

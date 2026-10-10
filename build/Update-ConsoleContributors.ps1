<#
.SYNOPSIS
    Writes the list of people for the Featured contributor panel of the console dashboard.

.DESCRIPTION
    Reads the contributor data of the website (website/src/data/contributors.json, which the website's own
    tooling derives from the git history) and writes what the panel shows: the name, the GitHub handle, how
    many tests the person wrote, how many they improved, and the year of their first contribution. The list
    ships with the module, so a run looks nothing up.

    People who are pinned last on the contributors page are left out, as they are from its highlights.

    Run it without parameters to refresh powershell/assets/ConsoleContributors.json. Build-MaesterModule.ps1
    runs it for the built module, so a release always has the current list. Do not edit the file by hand.

.PARAMETER Source
    The contributor data of the website.

.PARAMETER Destination
    The file to write.

.EXAMPLE
    ./build/Update-ConsoleContributors.ps1
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string] $Source = "$PSScriptRoot/../website/src/data/contributors.json",

    [Parameter()]
    [string] $Destination = "$PSScriptRoot/../powershell/assets/ConsoleContributors.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$data = Get-Content -LiteralPath $Source -Raw | ConvertFrom-Json
$lines = foreach ($profile in $data.profiles) {
    $has = { param($name) $profile.PSObject.Properties[$name] -and $null -ne $profile.$name }
    if ((& $has 'pinLast') -and $profile.pinLast) { continue }
    if (-not (& $has 'github') -or -not $profile.github) { continue }
    $since = if ((& $has 'firstContribution') -and "$($profile.firstContribution)" -match '^(\d{4})') { [int]$Matches[1] } else { 0 }
    [ordered]@{
        Name         = if ((& $has 'name') -and $profile.name) { [string]$profile.name } else { [string]$profile.github }
        GitHub       = [string]$profile.github
        Tests        = if (& $has 'testsAuthored') { @($profile.testsAuthored).Count } else { 0 }
        Improvements = if (& $has 'testsContributed') { @($profile.testsContributed).Count } else { 0 }
        Since        = $since
    } | ConvertTo-Json -Compress
}

# One person to a line, so that a change to the list reads well in a diff.
$json = "[`n" + (@($lines) -join ",`n") + "`n]`n"
$folder = Split-Path -Path $Destination -Parent
if (-not (Test-Path -LiteralPath $folder)) { $null = New-Item -ItemType Directory -Path $folder -Force }
[System.IO.File]::WriteAllText($Destination, $json, [System.Text.UTF8Encoding]::new($false))
Write-Information "   Generated: $(Split-Path -Path $Destination -Leaf) ($(@($lines).Count) contributors)" -InformationAction Continue

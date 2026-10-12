[CmdletBinding()]
Param(
    [Parameter()]
    [string]$ModuleRoot = "$($env:GITHUB_WORKSPACE)/powershell",

    [Parameter()]
    [switch]$preview = $false
)

. "$PSScriptRoot/Get-NextModuleVersion.ps1"

$ManifestPath = "$($ModuleRoot)/Maester.psd1"

if ( -not (Test-Path $ManifestPath )) {
    Write-Error "Could not find PowerShell module manifest ($ManifestPath)"
    throw
} else {
    $major = 3 # Update this to change the major version number of Maester.

    # The latest stable release decides the number of the next release. A preview is a prerelease of that
    # number: 3.0.0-preview1, 3.0.0-preview2, then 3.0.0. See Get-NextModuleVersion.ps1.
    $stableVersion = [version](Find-Module -Name Maester).Version
    Write-Host "Latest stable version: $stableVersion"
    $published = @()
    if ($preview) { $published = @((Find-Module -Name Maester -AllVersions -AllowPrerelease).Version | ForEach-Object { [string]$_ }) }

    $next = Get-NextModuleVersion -StableVersion $stableVersion -PublishedVersion $published -Major $major -Preview:$preview

    $publicScripts = @( Get-ChildItem -Path "$ModuleRoot/public" -Recurse -Filter "*.ps1" )
    $FunctionNames = @( $publicScripts.BaseName | Sort-Object )

    Update-ModuleManifest -Path $ManifestPath -ModuleVersion $next.ModuleVersion -FunctionsToExport $FunctionNames -Prerelease $next.Prerelease
}

$NewVersion = $next.FullVersion
Write-Host "New version: $NewVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "newtag=$NewVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "tag=$NewVersion"

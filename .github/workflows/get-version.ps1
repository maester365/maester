[CmdletBinding()]
Param(
    [Parameter()]
    [string]$ModuleRoot = "$($env:GITHUB_WORKSPACE)/powershell"
)

$ManfifestPath = "$($ModuleRoot)/Maester.psd1"

if ( -not (Test-Path $ManfifestPath )) {
    Write-Error "Could not find PowerShell module manifest ($ManfifestPath)"
    throw
} else {
    # Get the current version of the module from the module manifest
    $Version = (Test-ModuleManifest $ManfifestPath).Version
    $Version = '{0}.{1}.{2}' -f $Version.Major, $Version.Minor, $Version.Build
}

Add-Content -Path $env:GITHUB_OUTPUT -Value "tag=$Version"

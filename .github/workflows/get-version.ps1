[CmdletBinding()]
Param(
    [Parameter()]
    [string]$ModuleRoot = "$($env:GITHUB_WORKSPACE)/powershell"
)

$ManifestPath = "$($ModuleRoot)/Maester.psd1"

if ( -not (Test-Path $ManifestPath )) {
    Write-Error "Could not find PowerShell module manifest ($ManifestPath)"
    throw
} else {
    # Get the current version of the module from the module manifest
    $Version = (Test-ModuleManifest $ManifestPath).Version
    $Version = '{0}.{1}.{2}' -f $Version.Major, $Version.Minor, $Version.Build
}

Add-Content -Path $env:GITHUB_OUTPUT -Value "tag=$Version"

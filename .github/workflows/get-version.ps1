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
    $Version = (Find-Module -Name Maester).Version
}

Add-Content -Path $env:GITHUB_OUTPUT -Value "tag=$Version"

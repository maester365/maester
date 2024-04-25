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
    $ver = [version](Find-Module -Name Maester).Version
    $newBuild = $ver.Build + 1
    $NewVersion = '{0}.{1}.{2}' -f $ver.Major, $ver.Minor, $newBuild

    $publicScripts = @( Get-ChildItem -Path "$ModuleRoot/public" -Recurse -Filter "*.ps1" )
    $FunctionNames = @( $publicScripts.BaseName | Sort-Object )

    Update-ModuleManifest -Path $ManfifestPath -ModuleVersion $NewVersion -FunctionsToExport $FunctionNames
}

Add-Content -Path $env:GITHUB_OUTPUT -Value "newtag=$NewVersion"

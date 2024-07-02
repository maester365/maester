[CmdletBinding()]
Param(
    [Parameter()]
    [string]$ModuleRoot = "$($env:GITHUB_WORKSPACE)/powershell",

    [Parameter()]
    [switch]$preview = $false
)

$ManfifestPath = "$($ModuleRoot)/Maester.psd1"

if ( -not (Test-Path $ManfifestPath )) {
    Write-Error "Could not find PowerShell module manifest ($ManfifestPath)"
    throw
} else {
    # Get the current version of the module from the PowerShell gallery
    $ver = [version](Find-Module -Name Maester -AllowPrerelease:$preview).Version
    $newBuild = $ver.Build + 1
    $NewVersion = '{0}.{1}.{2}' -f $ver.Major, $ver.Minor, $newBuild

    $publicScripts = @( Get-ChildItem -Path "$ModuleRoot/public" -Recurse -Filter "*.ps1" )
    $FunctionNames = @( $publicScripts.BaseName | Sort-Object )

    $previewLabel = if ($preview) { '-preview' } else { '' }

    Update-ModuleManifest -Path $ManfifestPath -ModuleVersion $NewVersion -FunctionsToExport $FunctionNames -Prerelease $previewLabel
}

$NewVersion += $previewLabel
Write-Output "Version set to $NewVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "newtag=$NewVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "tag=$NewVersion"

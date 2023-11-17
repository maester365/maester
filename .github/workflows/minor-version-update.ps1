[CmdletBinding()]
Param(
    [Parameter()]
    [string]$ModuleRoot = "$($env:GITHUB_WORKSPACE)/src"
)

$ManfifestPath = "$($ModuleRoot)/Maester.psd1"

if ( -not (Test-Path $ManfifestPath )) {
    Write-Error "Could not find PowerShell module manifest ($ManfifestPath)"
    throw
} else {
    [version]$CurrentVersion = Import-PowerShellDataFile $ManfifestPath | Select-Object -ExpandProperty ModuleVersion
    $NewVersion = "{0}.{1}.{2}" -f $CurrentVersion.Major, $CurrentVersion.Minor, ( $CurrentVersion.Build + 1 )

    $publicScripts = @( Get-ChildItem -Path "$ModuleRoot/public" -Recurse -Filter "*.ps1" )
    $FunctionNames = @( $publicScripts.BaseName | Sort-Object )

    Update-ModuleManifest -Path $ManfifestPath -ModuleVersion $NewVersion -FunctionsToExport $FunctionNames
}

Add-Content -Path $env:GITHUB_OUTPUT -Value "newtag=$NewVersion"

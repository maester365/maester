[CmdletBinding()]
Param(
    [Parameter()]
    [string]$ModuleRoot = "$($env:GITHUB_WORKSPACE)/powershell",

    [Parameter()]
    [switch]$preview = $false
)

$ManifestPath = "$($ModuleRoot)/Maester.psd1"

if ( -not (Test-Path $ManifestPath )) {
    Write-Error "Could not find PowerShell module manifest ($ManifestPath)"
    throw
} else {
    # Get the current version of the module from the PowerShell gallery
    $previousVersion = (Find-Module -Name Maester -AllowPrerelease:$preview).Version
    Write-Host "Previous version: $previousVersion"

    $ver = [version]($previousVersion -replace '-preview')

    # Set new version number. If it is pre-release, increment the build number otherwise increment the minor version.
    $major = 2 # Update this to change the major version number of Maester.
    if ($major -ne $ver.Major) {
        $minor = 0 # Reset the minor & build version when incrementing the major version.
        $build = 0
    } else {
        $minor = $ver.Minor

        if ($preview) {
            $build = $ver.Build + 1
        } else {
            $minor = $ver.Minor + 1
            $build = 0 # Reset the build number when incrementing the minor version.
        }
    }

    $NewVersion = '{0}.{1}.{2}' -f $major, $minor, $build

    $publicScripts = @( Get-ChildItem -Path "$ModuleRoot/public" -Recurse -Filter "*.ps1" )
    $FunctionNames = @( $publicScripts.BaseName | Sort-Object )

    $previewLabel = if ($preview) { '-preview' } else { '' }

    Update-ModuleManifest -Path $ManifestPath -ModuleVersion $NewVersion -FunctionsToExport $FunctionNames -Prerelease $previewLabel
}

$NewVersion += $previewLabel
Write-Host "New version: $NewVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "newtag=$NewVersion"
Add-Content -Path $env:GITHUB_OUTPUT -Value "tag=$NewVersion"

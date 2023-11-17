param
(
    # Directory used to base all relative paths
    [Parameter(Mandatory = $false)]
    [string] $BaseDirectory = "..\",
    #
    [Parameter(Mandatory = $false)]
    [string] $PackagesConfigPath = ".\packages.config",
    #
    [Parameter(Mandatory = $false)]
    [string] $NuGetConfigPath,
    #
    [Parameter(Mandatory = $false)]
    [string] $OutputDirectory,
    #
    [Parameter(Mandatory = $false)]
    [string] $NuGetPath = ".\build",
    #
    [Parameter(Mandatory = $false)]
    [uri] $NuGetUri = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
)

## Initialize
Remove-Module CommonFunctions -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot\CommonFunctions.psm1 -DisableNameChecking

[System.IO.DirectoryInfo] $BaseDirectoryInfo = Get-PathInfo $BaseDirectory -InputPathType Directory -ErrorAction Stop
[System.IO.FileInfo] $PackagesConfigFileInfo = Get-PathInfo $PackagesConfigPath -DefaultDirectory $BaseDirectoryInfo.FullName -DefaultFilename "packages.config" -ErrorAction Stop
[System.IO.FileInfo] $NuGetConfigFileInfo = Get-PathInfo $NuGetConfigPath -DefaultDirectory $BaseDirectoryInfo.FullName -DefaultFilename "NuGet.config" -SkipEmptyPaths
[System.IO.DirectoryInfo] $OutputDirectoryInfo = Get-PathInfo $OutputDirectory -InputPathType Directory -DefaultDirectory $BaseDirectoryInfo.FullName -SkipEmptyPaths -ErrorAction SilentlyContinue
[System.IO.FileInfo] $NuGetFileInfo = Get-PathInfo $NuGetPath -DefaultDirectory $BaseDirectoryInfo.FullName -DefaultFilename "nuget.exe" -ErrorAction SilentlyContinue
#Set-Alias nuget -Value $itemNuGetPath.FullName

## Download NuGet
if (!$NuGetFileInfo.Exists) {
    Invoke-WebRequest $NuGetUri.AbsoluteUri -UseBasicParsing -OutFile $NuGetFileInfo.FullName
}

## Run NuGet
$argsNuget = New-Object System.Collections.Generic.List[string]
$argsNuget.Add('restore')
$argsNuget.Add($PackagesConfigFileInfo.FullName)
if ($VerbosePreference -eq 'Continue') {
    $argsNuget.Add('-Verbosity')
    $argsNuget.Add('Detailed')
}
if ($NuGetConfigFileInfo) {
    $argsNuget.Add('-ConfigFile')
    $argsNuget.Add($NuGetConfigFileInfo.FullName)
}
if ($OutputDirectoryInfo) {
    $argsNuget.Add('-OutputDirectory')
    $argsNuget.Add($OutputDirectoryInfo.FullName)
}

Use-StartProcess $NuGetFileInfo.FullName -ArgumentList $argsNuget

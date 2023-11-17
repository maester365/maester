param
(
    # Path to Module Manifest
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\src\*.psd1",
    #
    [Parameter(Mandatory = $false)]
    [string] $PSModuleCacheDirectory = ".\build\TestResults\PSModuleCache",
    # 
    [Parameter(Mandatory = $false)]
    [string[]] $Repository = "PSGallery",
    # 
    [Parameter(Mandatory = $false)]
    [switch] $SkipExternalModuleDependencies
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop
#$PSModulePathBackup = $env:PSModulePath

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" -ErrorAction Stop | Select-Object -Last 1
[System.IO.DirectoryInfo] $PSModuleCacheDirectoryInfo = Get-PathInfo $PSModuleCacheDirectory -InputPathType Directory -SkipEmptyPaths -ErrorAction SilentlyContinue

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName

## Restore Nuget Packages
#.\build\Restore-NugetPackages.ps1 -BaseDirectory ".\" -Verbose:$false

## Create directory
if ($ModuleManifest['RequiredModules']) {
    Assert-DirectoryExists $PSModuleCacheDirectoryInfo.FullName -ErrorAction Stop | Out-Null
    if (!$env:PSModulePath.Contains($PSModuleCacheDirectoryInfo.FullName)) { $env:PSModulePath += '{0}{1}' -f [IO.Path]::PathSeparator, $PSModuleCacheDirectoryInfo.FullName }
}

## Save Module Dependencies
foreach ($Module in $ModuleManifest['RequiredModules']) {
    if (!(Get-Module -FullyQualifiedName $Module -ListAvailable -ErrorAction SilentlyContinue)) {
        $paramSaveModule = @{}
        if ($Module -is [hashtable]) {
            $paramSaveModule['Name'] = $Module.ModuleName
            if ($Module.ContainsKey('ModuleVersion')) { $paramSaveModule['MinimumVersion'] = $Module.ModuleVersion }
            elseif ($Module.ContainsKey('RequiredVersion')) { $paramSaveModule['RequiredVersion'] = $Module.RequiredVersion }
        }
        else { $paramSaveModule['Name'] = $Module }

        if (!$SkipExternalModuleDependencies -or $paramSaveModule['Name'] -notin $ModuleManifest.PrivateData.PSData['ExternalModuleDependencies']) {
            Save-Module -Repository $Repository -Path $PSModuleCacheDirectoryInfo.FullName @paramSaveModule
        }
    }
}

#$env:PSModulePath = $PSModulePathBackup

return $PSModuleCacheDirectoryInfo.FullName

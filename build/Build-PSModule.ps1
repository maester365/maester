param
(
    # Directory used to base all relative paths
    [Parameter(Mandatory = $false)]
    [string] $BaseDirectory = "..\",
    #
    [Parameter(Mandatory = $false)]
    [string] $OutputDirectory = ".\build\release\",
    #
    [Parameter(Mandatory = $false)]
    [string] $SourceDirectory = ".\src\",
    #
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath,
    #
    [Parameter(Mandatory = $false)]
    [string] $PackagesConfigPath = ".\packages.config",
    #
    [Parameter(Mandatory = $false)]
    [string] $PackagesDirectory = ".\build\packages",
    #
    [Parameter(Mandatory = $false)]
    [string] $LicensePath = ".\LICENSE",
    #
    [Parameter(Mandatory = $false)]
    [switch] $SkipMergingNestedModuleScripts
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop

[System.IO.DirectoryInfo] $BaseDirectoryInfo = Get-PathInfo $BaseDirectory -InputPathType Directory -ErrorAction Stop
[System.IO.DirectoryInfo] $OutputDirectoryInfo = Get-PathInfo $OutputDirectory -InputPathType Directory -DefaultDirectory $BaseDirectoryInfo.FullName -ErrorAction SilentlyContinue
[System.IO.DirectoryInfo] $SourceDirectoryInfo = Get-PathInfo $SourceDirectory -InputPathType Directory -DefaultDirectory $BaseDirectoryInfo.FullName -ErrorAction Stop
[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultDirectory $SourceDirectoryInfo.FullName -DefaultFilename "*.psd1" -ErrorAction Stop
[System.IO.FileInfo] $PackagesConfigFileInfo = Get-PathInfo $PackagesConfigPath -DefaultDirectory $BaseDirectoryInfo.FullName -DefaultFilename "packages.config" -ErrorAction SilentlyContinue
[System.IO.DirectoryInfo] $PackagesDirectoryInfo = Get-PathInfo $PackagesDirectory -InputPathType Directory -DefaultDirectory $BaseDirectoryInfo.FullName -ErrorAction SilentlyContinue
[System.IO.FileInfo] $LicenseFileInfo = Get-PathInfo $LicensePath -DefaultDirectory $BaseDirectoryInfo.FullName -DefaultFilename "LICENSE" -ErrorAction SilentlyContinue

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName
[System.IO.DirectoryInfo] $ModuleOutputDirectoryInfo = Join-Path $OutputDirectoryInfo.FullName (Join-Path $ModuleManifestFileInfo.BaseName $ModuleManifest['ModuleVersion'])
[System.IO.FileInfo] $OutputModuleManifestFileInfo = Join-Path $ModuleOutputDirectoryInfo.FullName $ModuleManifestFileInfo.Name

## Copy Source Module Code to Module Output Directory
Assert-DirectoryExists $ModuleOutputDirectoryInfo -ErrorAction Stop | Out-Null
Copy-Item ("{0}\*" -f $SourceDirectoryInfo.FullName) -Destination $ModuleOutputDirectoryInfo.FullName -Recurse -Force
if (!$SkipMergingNestedModuleScripts) {
    [System.IO.FileInfo] $OutputRootModuleFileInfo = (Join-Path $ModuleOutputDirectoryInfo.FullName $ModuleManifest['RootModule'])
    &$PSScriptRoot\Merge-PSModuleNestedModuleScripts.ps1 -ModuleManifestPath $OutputModuleManifestFileInfo.FullName -OutputModulePath $OutputRootModuleFileInfo.FullName -MergeWithRootModule -RemoveNestedModuleScriptFiles
}
if ($LicenseFileInfo.Exists) {
    Copy-Item $LicenseFileInfo.FullName -Destination (Join-Path $ModuleOutputDirectoryInfo.FullName License.txt) -Force
}

if ($PackagesConfigFileInfo.Exists) {
    ## NuGet Restore
    &$PSScriptRoot\Restore-NugetPackages.ps1 -PackagesConfigPath $PackagesConfigFileInfo.FullName -OutputDirectory $PackagesDirectoryInfo.FullName

    ## Read Packages Configuration
    $xmlPackagesConfig = New-Object xml
    $xmlPackagesConfig.Load($PackagesConfigFileInfo.FullName)

    ## Copy Packages to Module Output Directory
    foreach ($package in $xmlPackagesConfig.packages.package) {
        [string[]] $targetFrameworks = $package.targetFramework
        if (!$targetFrameworks) { [string[]] $targetFrameworks = "net45", "netcoreapp2.1" }
        foreach ($targetFramework in $targetFrameworks) {
            [System.IO.DirectoryInfo] $PackageDirectory = Join-Path $PackagesDirectoryInfo.FullName ("{0}.{1}\lib\{2}" -f $package.id, $package.version, $targetFramework)
            [System.IO.DirectoryInfo] $PackageOutputDirectory = "{0}\{1}.{2}\{3}" -f $ModuleOutputDirectoryInfo.FullName, $package.id, $package.version, $targetFramework
            $PackageOutputDirectory
            Assert-DirectoryExists $PackageOutputDirectory -ErrorAction Stop | Out-Null
            Copy-Item ("{0}\*" -f $PackageDirectory) -Destination $PackageOutputDirectory.FullName -Recurse -Force
        }
    }
}

## Get Module Output FileList
#$ModuleFileListFileInfo = Get-ChildItem $ModuleOutputDirectoryInfo.FullName -Recurse -File
#$ModuleManifestOutputFileInfo = $ModuleFileListFileInfo | Where-Object Name -EQ $ModuleManifestFileInfo.Name

## Update Module Manifest in Module Output Directory
&$PSScriptRoot\Update-PSModuleManifest.ps1 -ModuleManifestPath $OutputModuleManifestFileInfo.FullName
if (!$SkipMergingNestedModuleScripts) {
    &$PSScriptRoot\Add-PSModuleHeader.ps1 -ModuleManifestPath $OutputModuleManifestFileInfo.FullName
}

## Sign Module
&$PSScriptRoot\Sign-PSModule.ps1 -ModuleManifestPath $OutputModuleManifestFileInfo.FullName | Format-Table Path, Status, StatusMessage

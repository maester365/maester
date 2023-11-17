param
(
    # Path to Module Manifest
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\release\*\*.*.*",
    # Specifies a unique identifier for the module.
    [Parameter(Mandatory = $false)]
    [string] $Guid,
    # Specifies the version of the module.
    [Parameter(Mandatory = $false)]
    [string] $ModuleVersion,
    # Indicates the module is prerelease.
    [Parameter(Mandatory = $false)]
    [string] $Prerelease,
    # Skip automatic additions to RequiredAssemblies from module file list.
    [Parameter(Mandatory = $false)]
    [switch] $SkipRequiredAssembliesDetection
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop
[hashtable] $paramUpdateModuleManifest = @{ }

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" -ErrorAction Stop
#[System.IO.DirectoryInfo] $ModuleOutputDirectoryInfo = $ModuleManifestFileInfo.Directory

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName
$paramUpdateModuleManifest['NestedModules'] = $ModuleManifest['NestedModules'] | Where-Object { $null -ne $_ -and (Get-PathInfo $_ -DefaultDirectory $ModuleManifestFileInfo.DirectoryName -ErrorAction Ignore).Exists }
$paramUpdateModuleManifest['FunctionsToExport'] = $ModuleManifest['FunctionsToExport']
$paramUpdateModuleManifest['CmdletsToExport'] = $ModuleManifest['CmdletsToExport']
$paramUpdateModuleManifest['AliasesToExport'] = $ModuleManifest['AliasesToExport']
if ($ModuleManifest.PrivateData.PSData['Prerelease'] -eq 'source') { $paramUpdateModuleManifest['Prerelease'] = " " }

## Override from Parameters
if ($Guid) { $paramUpdateModuleManifest['Guid'] = $Guid }
if ($ModuleVersion) { $paramUpdateModuleManifest['ModuleVersion'] = $ModuleVersion }
if ($Prerelease) { $paramUpdateModuleManifest['Prerelease'] = $Prerelease }

## Get Module Output FileList
$ModuleFileListFileInfo = Get-ChildItem $ModuleManifestFileInfo.DirectoryName -Recurse -File
$ModuleRequiredAssembliesFileInfo = $ModuleFileListFileInfo | Where-Object Extension -EQ '.dll'

## Get Paths Relative to Module Base Directory
$ModuleFileList = Get-RelativePath $ModuleFileListFileInfo.FullName -WorkingDirectory $ModuleManifestFileInfo.DirectoryName -ErrorAction Stop
$ModuleFileList = $ModuleFileList -replace '\\net45\\', '\!!!\' -replace '\\netcoreapp2.1\\', '\net45\' -replace '\\!!!\\', '\netcoreapp2.1\'  # PowerShell Core fails to load assembly if net45 dll comes before netcoreapp2.1 dll in the FileList.
$paramUpdateModuleManifest['FileList'] = $ModuleFileList

## Generate RequiredAssemblies list based on existing items and file list
$paramUpdateModuleManifest['RequiredAssemblies'] = $ModuleManifest['RequiredAssemblies'] | Where-Object { $_ -notin $ModuleFileListFileInfo.Name }
if (!$SkipRequiredAssembliesDetection -and $ModuleRequiredAssembliesFileInfo) {
    $ModuleRequiredAssemblies = Get-RelativePath $ModuleRequiredAssembliesFileInfo.FullName -WorkingDirectory $ModuleManifestFileInfo.DirectoryName -ErrorAction Stop
    $paramUpdateModuleManifest['RequiredAssemblies'] += $ModuleRequiredAssemblies
}

## Clear Existing RequiredAssemblies, NestedModules, and FileList
if ($paramUpdateModuleManifest.ContainsKey('RequiredAssemblies')) {
    if (!$paramUpdateModuleManifest['RequiredAssemblies']) { $paramUpdateModuleManifest.Remove('RequiredAssemblies') }
    (Get-Content $ModuleManifestFileInfo.FullName -Raw) -replace "(?s)(#\s*)?RequiredAssemblies\s*=\s*@\([^)]*\)", "# RequiredAssemblies = @()" | Set-Content $ModuleManifestFileInfo.FullName
}
if ($paramUpdateModuleManifest.ContainsKey('NestedModules') -and !$paramUpdateModuleManifest['NestedModules']) {
    $paramUpdateModuleManifest.Remove('NestedModules')
    (Get-Content $ModuleManifestFileInfo.FullName -Raw) -replace "(?s)(#\s*)?NestedModules\s*=\s*@\([^)]*\)", "# NestedModules = @()" | Set-Content $ModuleManifestFileInfo.FullName
}
if ($paramUpdateModuleManifest.ContainsKey('FileList')) {
    (Get-Content $ModuleManifestFileInfo.FullName -Raw) -replace "(?s)(#\s*)?FileList\s*=\s*@\([^)]*\)", "# FileList = @()" | Set-Content $ModuleManifestFileInfo.FullName
}

## Install Module Dependencies
foreach ($Module in $ModuleManifest['RequiredModules']) {
    if ($Module -is [hashtable]) { $ModuleName = $Module.ModuleName }
    else { $ModuleName = $Module }
    if ($ModuleName -notin $ModuleManifest.PrivateData.PSData['ExternalModuleDependencies'] -and !(Get-Module $ModuleName -ListAvailable)) {
        Install-Module $ModuleName -Force -SkipPublisherCheck -Repository PSGallery -AcceptLicense
    }
}

## Update Module Manifest in Module Output Directory
Update-ModuleManifest -Path $ModuleManifestFileInfo.FullName -ErrorAction Stop @paramUpdateModuleManifest

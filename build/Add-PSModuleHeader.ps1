param
(
    # Path to Module Manifest
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\release\*\*.*.*",
    #
    [Parameter(Mandatory = $false)]
    [string] $OutputModulePath
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" -ErrorAction Stop

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName

if ($OutputModulePath) {
    [System.IO.FileInfo] $OutputModuleFileInfo = Get-PathInfo $OutputModulePath -InputPathType File -DefaultFilename "$($ModuleManifestFileInfo.BaseName).psm1" -ErrorAction SilentlyContinue
}
else {
    [System.IO.FileInfo] $OutputModuleFileInfo = Get-PathInfo $ModuleManifest['RootModule'] -InputPathType File -DefaultDirectory $ModuleManifestFileInfo.DirectoryName -ErrorAction SilentlyContinue
}

if ($OutputModuleFileInfo.Extension -eq ".psm1") {
    ## Add Requires Statements
    $RequiresStatements = ""
    if ($ModuleManifest['PowerShellVersion']) { $RequiresStatements += "#Requires -Version {0}`r`n" -f $ModuleManifest['PowerShellVersion'] }
    if ($ModuleManifest['CompatiblePSEditions']) { $RequiresStatements += "#Requires -PSEdition {0}`r`n" -f ($ModuleManifest['CompatiblePSEditions'] -join ',') }
    foreach ($RequiredAssembly in $ModuleManifest['RequiredAssemblies']) {
        $RequiresStatements += "#Requires -Assembly $_`r`n"
    }
    foreach ($RequiredModule in $ModuleManifest['RequiredModules']) {
        $RequiresStatements += ConvertTo-PsString $ModuleManifest['RequiredModules'] -Compact -RemoveTypes ([hashtable], [string]) | ForEach-Object { "#Requires -Module $_`r`n" }
    }

    ## Build Module Comment Header
    [string] $CommentHeader = "<#`r`n"
    $CommentHeader += ".SYNOPSIS`r`n    {0}`r`n" -f $ModuleManifestFileInfo.BaseName

    if ($ModuleManifest['Description']) {
        $CommentHeader += ".DESCRIPTION`r`n    {0}`r`n" -f $ModuleManifest['Description']
    }

    [string]$ModuleVersion = if ($ModuleManifest.PrivateData.PSData['Prerelease']) { '{0}-{1}' -f $ModuleManifest['ModuleVersion'], $ModuleManifest.PrivateData.PSData['Prerelease'] } else { $ModuleManifest['ModuleVersion'] }
    $CommentHeader += ".NOTES`r`n"
    $CommentHeader += "    ModuleVersion: {0}`r`n" -f $ModuleVersion
    if ($ModuleManifest['GUID']) { $CommentHeader += "    GUID: {0}`r`n" -f $ModuleManifest['GUID'] }
    if ($ModuleManifest['Author']) { $CommentHeader += "    Author: {0}`r`n" -f $ModuleManifest['Author'] }
    if ($ModuleManifest['CompanyName']) { $CommentHeader += "    CompanyName: {0}`r`n" -f $ModuleManifest['CompanyName'] }
    if ($ModuleManifest['Copyright']) { $CommentHeader += "    Copyright: {0}`r`n" -f $ModuleManifest['Copyright'] }
    if ($ModuleManifest['FunctionsToExport']) {
        ## ToDo: Account for modules with functions and/or cmdlets.
        $CommentHeader += ".FUNCTIONALITY`r`n    {0}`r`n" -f ($ModuleManifest['FunctionsToExport'] -join ', ')
    }
    if ($ModuleManifest.PrivateData.PSData['ProjectUri']) {
        $CommentHeader += ".LINK`r`n    {0}`r`n" -f $ModuleManifest.PrivateData.PSData['ProjectUri']
    }
    $CommentHeader += "#>"

    ## Add Comment Header to Script Module
    if ($OutputModuleFileInfo.Exists) {
        $RootModuleContent = (Get-Content $OutputModuleFileInfo.FullName -Raw)
    }
    else {
        $RootModuleContent = $null
    }

    $RequiresStatements, $CommentHeader, $RootModuleContent | Set-Content $OutputModuleFileInfo.FullName -Encoding utf8BOM
}

#Requires -Version 7.0
param
(
    # Path to Module Manifest
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\release\*\*.*.*\*.psd1",
    # Repository for PowerShell Gallery
    [Parameter(Mandatory = $false)]
    [string] $RepositorySourceLocation = 'https://www.powershellgallery.com/api/v2',
    # API Key for PowerShell Gallery
    [Parameter(Mandatory = $true)]
    [securestring] $NuGetApiKey,
    # Unlist from PowerShell Gallery
    [Parameter(Mandatory = $false)]
    [switch] $Unlist
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" -ErrorAction Stop | Select-Object -Last 1

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName

## Install Module Dependencies
foreach ($Module in $ModuleManifest['RequiredModules']) {
    if ($Module -is [hashtable]) { $ModuleName = $Module.ModuleName }
    else { $ModuleName = $Module }
    if ($ModuleName -notin $ModuleManifest.PrivateData.PSData['ExternalModuleDependencies'] -and !(Get-Module $ModuleName -ListAvailable)) {
        Install-Module $ModuleName -Force -SkipPublisherCheck -Repository PSGallery -AcceptLicense
    }
}

## Publish
$PSRepositoryAll = Get-PSRepository
$PSRepository = $PSRepositoryAll | Where-Object SourceLocation -Like "$RepositorySourceLocation*"
if (!$PSRepository) {
    try {
        [string] $RepositoryName = New-Guid
        Register-PSRepository $RepositoryName -SourceLocation $RepositorySourceLocation
        $PSRepository = Get-PSRepository $RepositoryName
        Publish-Module -Path $ModuleManifestFileInfo.DirectoryName -NuGetApiKey (ConvertFrom-SecureString $NuGetApiKey -AsPlainText) -Repository $PSRepository.Name
    }
    finally {
        Unregister-PSRepository $RepositoryName
    }
}
else {
    Write-Verbose ('Publishing Module Path [{0}]' -f $ModuleManifestFileInfo.DirectoryName)
    Publish-Module -Path $ModuleManifestFileInfo.DirectoryName -NuGetApiKey (ConvertFrom-SecureString $NuGetApiKey -AsPlainText) -Repository $PSRepository.Name
}

## Unlist the Package
if ($Unlist) {
    if ($ModuleManifest.PrivateData.PSData['Prerelease']) {
        Invoke-RestMethod -Method Delete -Uri ("{0}/{1}/{2}-{3}" -f $PSRepository.PublishLocation, $ModuleManifestFileInfo.BaseName, $ModuleManifest['ModuleVersion'], $ModuleManifest.PrivateData.PSData['Prerelease']) -Headers @{ 'X-NuGet-ApiKey' = ConvertFrom-SecureString $NuGetApiKey -AsPlainText }
    }
    else {
        Invoke-RestMethod -Method Delete -Uri ("{0}/{1}/{2}" -f $PSRepository.PublishLocation, $ModuleManifestFileInfo.BaseName, $ModuleManifest['ModuleVersion']) -Headers @{ 'X-NuGet-ApiKey' = ConvertFrom-SecureString $NuGetApiKey -AsPlainText }
    }
}

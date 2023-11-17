param
(
    # Path to Module Manifest
    [parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = "..\src",
    # Path to packages.config file
    [parameter(Mandatory = $false)]
    [string] $PackagesConfigPath = "..\",
    # Return trimmed version to the depth specified
    [parameter(Mandatory = $false)]
    [int] $TrimVersionDepth
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" -ErrorAction Stop
[System.IO.FileInfo] $PackagesConfigFileInfo = Get-PathInfo $PackagesConfigPath -DefaultFilename "packages.config" -ErrorAction SilentlyContinue

## Read Module Manifest
$ModuleManifest = Import-PowerShellDataFile $ModuleManifestFileInfo.FullName -ErrorAction Stop

## Output moduleName Azure Pipelines
$env:moduleName = $ModuleManifestFileInfo.BaseName
Write-Host ('##vso[task.setvariable variable=moduleName;isOutput=true]{0}' -f $env:moduleName)
Write-Host ('##[debug] {0} = {1}' -f 'moduleName', $env:moduleName)

## Output moduleVersion Azure Pipelines
$env:moduleVersion = $ModuleManifest['ModuleVersion']
Write-Host ('##vso[task.setvariable variable=moduleVersion;isOutput=true]{0}' -f $env:moduleVersion)
Write-Host ('##[debug] {0} = {1}' -f 'moduleVersion', $env:moduleVersion)

if ($TrimVersionDepth) {
    $env:moduleVersionTrimmed = $env:moduleVersion -replace ('(?<=^(.?[0-9]+){{{0},}})(.[0-9]+)+$' -f $TrimVersionDepth), ''
    Write-Host ('##vso[task.setvariable variable=moduleVersionTrimmed;isOutput=true]{0}' -f $env:moduleVersionTrimmed)
    Write-Host ('##[debug] {0} = {1}' -f 'moduleVersionTrimmed', $env:moduleVersionTrimmed)
}

## Read Packages Configuration
if ($PackagesConfigFileInfo.Exists) {
    $xmlPackagesConfig = New-Object xml
    $xmlPackagesConfig.Load($PackagesConfigFileInfo.FullName)

    foreach ($package in $xmlPackagesConfig.packages.package) {
        ## Output packageVersion Azure Pipelines
        Set-Variable ('env:{0}' -f $package.id) -Value $package.version
        Write-Host ('##vso[task.setvariable variable=version.{0};isOutput=true]{1}' -f $package.id, $package.version)
        Write-Host ('##[debug] version.{0} = {1}' -f $package.id, $package.version)
    }
}

param
(
    #
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\src\*.psd1",
    #
    [Parameter(Mandatory = $false)]
    [string] $PSModuleCacheDirectory = ".\build\TestResults\PSModuleCache",
    #
    [Parameter(Mandatory = $false)]
    [string] $PesterConfigurationPath = ".\build\PesterConfiguration.psd1",
    #
    [Parameter(Mandatory = $false)]
    [string] $TestResultPath,
    #
    [Parameter(Mandatory = $false)]
    [string] $CodeCoveragePath,
    #
    [Parameter(Mandatory = $false)]
    [string] $ModuleTestsDirectory = ".\tests"
)

## Initialize
Import-Module "$PSScriptRoot\CommonFunctions.psm1" -Force -WarningAction SilentlyContinue -ErrorAction Stop

[System.IO.FileInfo] $ModuleManifestFileInfo = Get-PathInfo $ModuleManifestPath -DefaultFilename "*.psd1" -ErrorAction Stop | Select-Object -Last 1
[System.IO.FileInfo] $TestResultFileInfo = Get-PathInfo $TestResultPath -DefaultFilename 'TestResult.xml' -ErrorAction Ignore
[System.IO.FileInfo] $CodeCoverageFileInfo = Get-PathInfo $CodeCoveragePath -DefaultFilename 'CodeCoverage.xml' -ErrorAction Ignore
[System.IO.DirectoryInfo] $PSModuleCacheDirectoryInfo = Get-PathInfo $PSModuleCacheDirectory -InputPathType Directory -SkipEmptyPaths -ErrorAction SilentlyContinue
[System.IO.FileInfo] $PesterConfigurationFileInfo = Get-PathInfo $PesterConfigurationPath -DefaultFilename 'PesterConfiguration.psd1' -ErrorAction SilentlyContinue
[System.IO.DirectoryInfo] $ModuleTestsDirectoryInfo = Get-PathInfo $ModuleTestsDirectory -InputPathType Directory -ErrorAction SilentlyContinue

## Restore Module Dependencies
&$PSScriptRoot\Restore-PSModuleDependencies.ps1 -ModuleManifestPath $ModuleManifestPath -PSModuleCacheDirectory $PSModuleCacheDirectoryInfo.FullName | Out-Null

Import-Module Pester -MinimumVersion 5.0.0
#$PSModule = Import-Module $ModulePath -PassThru -Force

$PesterConfiguration = New-PesterConfiguration (Import-PowerShellDataFile $PesterConfigurationFileInfo.FullName)
$PesterConfiguration.Run.Container = New-PesterContainer -Path $ModuleTestsDirectoryInfo.FullName -Data @{ ModulePath = $ModuleManifestFileInfo.FullName }
$PesterConfiguration.CodeCoverage.Path = Split-Path $ModuleManifestFileInfo.FullName -Parent
if ($TestResultPath) { $PesterConfiguration.TestResult.OutputPath = $TestResultFileInfo.FullName }
if ($CodeCoveragePath) { $PesterConfiguration.CodeCoverage.OutputPath = $CodeCoverageFileInfo.FullName }
#$PesterConfiguration.CodeCoverage.OutputPath = [IO.Path]::ChangeExtension($PesterConfiguration.CodeCoverage.OutputPath.Value, "$($PSVersionTable.PSVersion).xml")
#$PesterConfiguration.TestResult.OutputPath = [IO.Path]::ChangeExtension($PesterConfiguration.TestResult.OutputPath.Value, "$($PSVersionTable.PSVersion).xml")
$PesterRun = Invoke-Pester -Configuration $PesterConfiguration
$PesterRun

## Return SucceededWithIssues when running in ADO Pipeline and a test fails.
if ($env:AGENT_ID -and $PesterRun -and $PesterRun.Result -ne 'Passed') { Write-Host '##vso[task.complete result=SucceededWithIssues;]FailedTest' }

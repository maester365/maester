#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Runs all Active Directory tests using Invoke-Maester on a domain controller and copies report files to build/activeDirectory folder.

.DESCRIPTION
    This script:
    1. Imports the Maester PowerShell module
    2. Runs all AD tests using Invoke-Maester
    3. Copies the generated report files (HTML, Markdown, JSON) to the build/activeDirectory folder

.PARAMETER MaesterModulePath
    Path to the Maester PowerShell module. Defaults to the local powershell folder.

.PARAMETER TestPath
    Path to the AD tests. Defaults to tests/Maester/ad and tests/ad.

.PARAMETER OutputFolder
    Temporary output folder for test results. Defaults to ./test-results.

.PARAMETER TargetFolder
    Target folder where reports will be copied. Defaults to build/activeDirectory.

.EXAMPLE
    .\Run-ADTests-And-CopyReports.ps1

    Runs all AD tests and copies reports to build/activeDirectory.

.EXAMPLE
    .\Run-ADTests-And-CopyReports.ps1 -MaesterModulePath "C:\Maester\powershell" -Verbose

    Runs tests using a specific Maester module path with verbose output.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string]$MaesterModulePath = (Join-Path $PSScriptRoot "..\..\powershell"),

    [Parameter()]
    [string]$TestPath = (Join-Path $PSScriptRoot "..\..\tests"),

    [Parameter()]
    [string]$OutputFolder = (Join-Path $PSScriptRoot "..\..\test-results"),

    [Parameter()]
    [string]$TargetFolder = $PSScriptRoot
)

#region Initialization
$ErrorActionPreference = "Stop"
$startTime = Get-Date

Write-Host "=== Maester Active Directory Test Runner ===" -ForegroundColor Cyan
Write-Host "Start Time: $startTime" -ForegroundColor Gray
Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "Domain: $env:USERDOMAIN" -ForegroundColor Gray
Write-Host ""

# Resolve absolute paths
$MaesterModulePath = Resolve-Path $MaesterModulePath -ErrorAction Stop
$TestPath = Resolve-Path $TestPath -ErrorAction Stop
$OutputFolder = Resolve-Path $OutputFolder -ErrorAction SilentlyContinue
if (-not $OutputFolder) {
    $OutputFolder = (Join-Path $PSScriptRoot "..\..\test-results")
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
    $OutputFolder = Resolve-Path $OutputFolder
}
$TargetFolder = Resolve-Path $TargetFolder -ErrorAction Stop

Write-Verbose "Maester Module Path: $MaesterModulePath"
Write-Verbose "Test Path: $TestPath"
Write-Verbose "Output Folder: $OutputFolder"
Write-Verbose "Target Folder: $TargetFolder"
#endregion

#region Module Import
Write-Host "[Step 1] Importing Maester module..." -ForegroundColor Yellow
try {
    $manifestPath = Join-Path $MaesterModulePath "Maester.psd1"
    if (-not (Test-Path $manifestPath)) {
        throw "Maester module manifest not found at: $manifestPath"
    }

    Import-Module $manifestPath -Force -Verbose:$VerbosePreference
    $module = Get-Module Maester
    Write-Host "  ✓ Maester module v$($module.Version) imported successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to import Maester module: $_"
    exit 1
}
#endregion

#region Pre-requisites Check
Write-Host "`n[Step 2] Checking pre-requisites..." -ForegroundColor Yellow

# Check if running on a domain-joined machine or DC
$computerInfo = Get-WmiObject -Class Win32_ComputerSystem
if (-not $computerInfo.PartOfDomain) {
    Write-Warning "This computer is not domain-joined. AD tests may fail."
}

# Check for required Windows modules
$requiredModules = @("ActiveDirectory", "GroupPolicy")
foreach ($moduleName in $requiredModules) {
    if (Get-Module -ListAvailable -Name $moduleName) {
        Write-Host "  ✓ $moduleName module available" -ForegroundColor Green
        try {
            Import-Module $moduleName -ErrorAction Stop
            Write-Host "    - $moduleName module imported" -ForegroundColor Gray
        } catch {
            Write-Warning "    - Failed to import $moduleName`: $_"
        }
    } else {
        Write-Warning "  ✗ $moduleName module not available"
    }
}

# Verify AD test paths
$adTestPaths = @(
    (Join-Path $TestPath "Maester\ad"),
    (Join-Path $TestPath "ad")
)

$validTestPaths = @()
foreach ($path in $adTestPaths) {
    if (Test-Path $path) {
        Write-Host "  ✓ Found AD tests at: $path" -ForegroundColor Green
        $validTestPaths += $path
    } else {
        Write-Verbose "  AD test path not found: $path"
    }
}

if ($validTestPaths.Count -eq 0) {
    Write-Error "No AD test paths found!"
    exit 1
}

Write-Host "  Found $($validTestPaths.Count) AD test location(s)" -ForegroundColor Gray
#endregion

#region Run AD Tests
Write-Host "`n[Step 3] Running Active Directory tests..." -ForegroundColor Yellow
Write-Host "  This may take several minutes depending on domain size..." -ForegroundColor Gray
Write-Host ""

try {
    # Create output folder if it doesn't exist
    if (-not (Test-Path $OutputFolder)) {
        New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
    }

    # Generate timestamped filename
    $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
    $fileName = "AD-TestResults-$timestamp"

    # Run Invoke-Maester for AD tests
    $invokeParams = @{
        Path = $TestPath
        OutputFolder = $OutputFolder
        OutputFolderFileName = $fileName
        NonInteractive = $true
        SkipGraphConnect = $true  # AD tests don't need Graph connection
        Verbosity = 'Normal'
    }

    Write-Host "  Running: Invoke-Maester with parameters:" -ForegroundColor Gray
    $invokeParams.GetEnumerator() | ForEach-Object {
        Write-Host "    - $($_.Key): $($_.Value)" -ForegroundColor Gray
    }
    Write-Host ""

    $results = Invoke-Maester @invokeParams -PassThru

    if ($results) {
        Write-Host "`n  ✓ Tests completed" -ForegroundColor Green
        Write-Host "    - Total Tests: $($results.TotalCount)" -ForegroundColor Gray
        Write-Host "    - Passed: $($results.PassedCount)" -ForegroundColor Green
        Write-Host "    - Failed: $($results.FailedCount)" -ForegroundColor $(if($results.FailedCount -gt 0){'Red'}else{'Gray'})
        Write-Host "    - Skipped: $($results.SkippedCount)" -ForegroundColor Gray

        # Get the generated files
        $generatedFiles = @(
            (Join-Path $OutputFolder "$fileName.html"),
            (Join-Path $OutputFolder "$fileName.md"),
            (Join-Path $OutputFolder "$fileName.json")
        ) | Where-Object { Test-Path $_ }

        Write-Host "`n  Generated files:" -ForegroundColor Gray
        $generatedFiles | ForEach-Object {
            $size = (Get-Item $_).Length
            Write-Host "    - $(Split-Path $_ -Leaf) ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Gray
        }
    } else {
        Write-Warning "No test results returned"
    }
} catch {
    Write-Error "Failed to run AD tests: $_"
    exit 1
}
#endregion

#region Copy Reports
Write-Host "`n[Step 4] Copying report files to target folder..." -ForegroundColor Yellow

try {
    $copiedFiles = @()
    $fileTypes = @("*.html", "*.md", "*.json", "*.csv", "*.xlsx")

    foreach ($fileType in $fileTypes) {
        $files = Get-ChildItem -Path $OutputFolder -Filter "$fileName$fileType" -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $targetPath = Join-Path $TargetFolder $file.Name
            Copy-Item -Path $file.FullName -Destination $targetPath -Force
            $copiedFiles += $targetPath
            Write-Host "  ✓ Copied: $($file.Name)" -ForegroundColor Green
        }
    }

    if ($copiedFiles.Count -eq 0) {
        Write-Warning "No files were copied. Check if tests generated output files."
    } else {
        Write-Host "`n  Successfully copied $($copiedFiles.Count) file(s) to:" -ForegroundColor Green
        Write-Host "  $TargetFolder" -ForegroundColor Gray
    }
} catch {
    Write-Error "Failed to copy report files: $_"
    exit 1
}
#endregion

#region Summary
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "`n=== Execution Summary ===" -ForegroundColor Cyan
Write-Host "Start Time: $startTime" -ForegroundColor Gray
Write-Host "End Time: $endTime" -ForegroundColor Gray
Write-Host "Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
Write-Host ""
Write-Host "Reports saved to:" -ForegroundColor Yellow
Write-Host "  $TargetFolder" -ForegroundColor Gray
Write-Host ""
Write-Host "Files generated:" -ForegroundColor Yellow
Get-ChildItem -Path $TargetFolder -Filter "AD-TestResults-*" | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "✓ AD Test execution completed successfully!" -ForegroundColor Green
#endregion

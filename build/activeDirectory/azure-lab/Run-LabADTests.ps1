#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Runs Maester AD tests against the azure-lab and retrieves reports.

.DESCRIPTION
    This script automates the full workflow for validating Maester AD test changes
    against the azure-lab environment:
    1. Builds the local Maester module from source
    2. Uses managed identity to retrieve lab credentials from Azure Key Vault
    3. Copies the built module to the Windows runner via SSH
    4. Executes AD tests against all configured domains
    5. Retrieves generated reports back to the local evidence directory

    Requires: Azure CLI (az), sshpass, pwsh, and SSH access to the Windows runner.

    TIMING WARNING: A full 3-domain test run takes approximately 25-30 minutes.
    If running via an automation platform with a command timeout, increase the
    timeout to at least 1800 seconds (30 minutes) or test domains individually.

.PARAMETER LabConfigPath
    Path to LabConfig.json. Defaults to ./build/activeDirectory/azure-lab/LabConfig.json

.PARAMETER EvidenceDir
    Local directory to store retrieved reports. Defaults to ./.sisyphus/evidence/lab-run-$(Get-Date -Format yyyyMMdd-HHmmss)

.PARAMETER SkipBuild
    Skip building the module. Use this if you have already built and want to re-run tests.

.PARAMETER Domains
    Which domains to test. Defaults to all domains in LabConfig. Options: RootForest, ChildDomain, SeparateForest.
    Use this to test a single domain when you have timeout constraints.

.PARAMETER Tag
    Test tag filter. Defaults to "AD".

.EXAMPLE
    ./Run-LabADTests.ps1
    Builds module, runs AD tests against all domains, retrieves reports.
    Expected runtime: 25-30 minutes.

.EXAMPLE
    ./Run-LabADTests.ps1 -Domains RootForest -SkipBuild
    Re-runs tests against root domain only without rebuilding.
    Expected runtime: 8-10 minutes.

.EXAMPLE
    ./Run-LabADTests.ps1 -Domains RootForest,ChildDomain
    Tests root and child domains. Expected runtime: 15-20 minutes.
#>
[CmdletBinding()]
param(
    [string]$LabConfigPath = "$PSScriptRoot/LabConfig.json",
    [string]$EvidenceDir = "$PSScriptRoot/../../../.sisyphus/evidence/lab-run-$(Get-Date -Format yyyyMMdd-HHmmss)",
    [switch]$SkipBuild,
    [ValidateSet('RootForest', 'ChildDomain', 'SeparateForest')]
    [string[]]$Domains = @('RootForest', 'ChildDomain', 'SeparateForest'),
    [string]$Tag = 'AD'
)

$ErrorActionPreference = 'Stop'

# --- Validate prerequisites ---
function Test-Prerequisite {
    param([string]$Name, [string]$Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Prerequisite missing: $Name ($Command). Please install it."
    }
}

Test-Prerequisite 'Azure CLI' 'az'
Test-Prerequisite 'sshpass' 'sshpass'
Test-Prerequisite 'PowerShell' 'pwsh'

# --- Load lab config ---
if (-not (Test-Path $LabConfigPath)) {
    throw "LabConfig not found at: $LabConfigPath"
}
$lab = Get-Content $LabConfigPath -Raw | ConvertFrom-Json

$winRunner = $lab.runners | Where-Object { $_.osType -eq 'Windows' }
$keyVault = $lab.credentials.keyVaultName
$resourceGroup = $lab.deployment.resourceGroupName

if (-not $winRunner) {
    throw "No Windows runner found in LabConfig."
}

Write-Output "Lab: $($lab.deployment.labPrefix) in $resourceGroup"
Write-Output "Windows runner: $($winRunner.azureVmName) at $($winRunner.publicIp)"
Write-Output "Key Vault: $keyVault"
Write-Output "Domains to test: $($Domains -join ', ')"
Write-Output "Evidence dir: $EvidenceDir"

# Timing estimate
$estimatedMinutes = $Domains.Count * 10
Write-Warning "Estimated runtime is ~$estimatedMinutes minutes for $($Domains.Count) domain(s)."
Write-Warning "If your execution environment has a command timeout, ensure it exceeds $([math]::Ceiling($estimatedMinutes * 1.5)) minutes."
Write-Warning "Test a single domain with: ./Run-LabADTests.ps1 -Domains RootForest"

# --- Ensure Azure login ---
$azAccount = az account show 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    Write-Output "Logging in to Azure with managed identity..."
    az login --identity | Out-Null
} else {
    Write-Output "Already logged in as: $($azAccount.user.name)"
}

# --- Build module ---
if (-not $SkipBuild) {
    Write-Output "Building Maester module..."
    $buildScript = "$PSScriptRoot/../../../build/Build-LocalMaester.ps1"
    if (-not (Test-Path $buildScript)) {
        throw "Build script not found: $buildScript"
    }
    & $buildScript
    if ($LASTEXITCODE -ne 0) {
        throw "Module build failed."
    }
    Write-Output "Module built successfully."
} else {
    Write-Output "Skipping module build (using existing)."
}

# --- Retrieve secrets ---
Write-Output "Retrieving credentials from Key Vault..."

function Get-KvSecret {
    param([string]$Name)
    $val = az keyvault secret show --vault-name $keyVault --name $Name --query value -o tsv 2>$null
    if (-not $val) {
        throw "Failed to retrieve secret: $Name from vault $keyVault"
    }
    return $val
}

$winPassword = Get-KvSecret -Name $lab.credentials.secretNames.windowsLocalAdminPassword
$readerPassword = Get-KvSecret -Name $lab.credentials.secretNames.rootDomainReaderPassword

# Child and forest may use same or different passwords
$childReaderPassword = $readerPassword
$forestReaderPassword = $readerPassword

try {
    $childReaderPassword = Get-KvSecret -Name $lab.credentials.secretNames.childDomainReaderPassword
} catch {
    Write-Verbose "Child domain reader password not found in Key Vault; using root domain reader password."
}
try {
    $forestReaderPassword = Get-KvSecret -Name $lab.credentials.secretNames.forestDomainReaderPassword
} catch {
    Write-Verbose "Forest domain reader password not found in Key Vault; using root domain reader password."
}

Write-Output "Credentials retrieved."

# --- Copy module to runner ---
Write-Output "Copying module to Windows runner..."
$moduleSource = "$PSScriptRoot/../../../module"
if (-not (Test-Path $moduleSource)) {
    throw "Built module not found at: $moduleSource. Run without -SkipBuild."
}

$sshTarget = "$($winRunner.adminUsername)@$($winRunner.publicIp)"
$env:SSHPASS = $winPassword

# Create remote dev directory and copy module
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
    $sshTarget 'New-Item -ItemType Directory -Force -Path C:\MaesterDev | Out-Null' 2>$null

# Tar and copy
$tarFile = "/tmp/maester-module-$(Get-Random).tar.gz"
tar -czf $tarFile -C $moduleSource .
sshpass -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
    $tarFile "$sshTarget`:C:\MaesterDev\module.tar.gz" 2>$null

# Extract on remote
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
    $sshTarget 'tar -xzf C:\MaesterDev\module.tar.gz -C C:\MaesterDev' 2>$null

Remove-Item $tarFile -ErrorAction SilentlyContinue
Write-Output "Module copied to C:\MaesterDev on runner."

# --- Run tests per domain ---
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

$testResults = @()
$overallStart = Get-Date

foreach ($domainRole in $Domains) {
    $dc = $lab.domainControllers | Where-Object { $_.role -eq $domainRole }
    if (-not $dc) {
        Write-Warning "No DC found for role: $domainRole"
        continue
    }

    $domainStart = Get-Date
    Write-Output ""
    Write-Output "========================================"
    Write-Output "Testing domain: $($dc.domain) ($domainRole)"
    Write-Output "Via DC: $($dc.fqdn)"
    Write-Output "Started at: $($domainStart.ToString('HH:mm:ss'))"
    Write-Output "========================================"

    $passwordToUse = $readerPassword
    if ($domainRole -eq 'ChildDomain') { $passwordToUse = $childReaderPassword }
    if ($domainRole -eq 'SeparateForest') { $passwordToUse = $forestReaderPassword }

    # Remote script with progress output so partial results are visible even on timeout
    $remoteScript = @"
`$ErrorActionPreference = 'Stop'
Write-Output "[$(Get-Date -Format 'HH:mm:ss')] Importing Maester module..."
Import-Module C:\MaesterDev\Maester.psd1 -Force

Write-Output "[$(Get-Date -Format 'HH:mm:ss')] Connecting to $($dc.domain)..."
`$cred = [PSCredential]::new('$($dc.domain)\$($lab.credentials.testUserName)', (ConvertTo-SecureString '$passwordToUse' -AsPlainText -Force))
Connect-Maester -Service ActiveDirectory -ActiveDirectoryCredential `$cred `
  -ActiveDirectoryServer '$($dc.fqdn)' -ActiveDirectoryDomain '$($dc.domain)' `
  -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode Ldaps
Write-Output "[$(Get-Date -Format 'HH:mm:ss')] Connection established."

`$reportDir = 'C:\MaesterReports\lab-run'
New-Item -ItemType Directory -Force -Path `$reportDir | Out-Null

Write-Output "[$(Get-Date -Format 'HH:mm:ss')] Starting test execution (270 tests, ~8-10 min)..."
Invoke-Maester -Tag $Tag -NonInteractive -SkipGraphConnect `
  -OutputFolder `$reportDir -OutputFolderFileName '$domainRole'
Write-Output "[$(Get-Date -Format 'HH:mm:ss')] TEST EXECUTION COMPLETE for $domainRole"
"@

    $remoteScriptPath = "/tmp/run-$domainRole-$(Get-Random).ps1"
    $remoteScript | Set-Content $remoteScriptPath

    # Copy script to runner
    sshpass -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        $remoteScriptPath "$sshTarget`:C:\tmp\run-$domainRole.ps1" 2>$null

    # Execute with progress tracking
    Write-Output "Executing remote script... (this takes ~8-10 minutes per domain)"
    $execResult = sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        $sshTarget "pwsh -ExecutionPolicy Bypass -File C:\tmp\run-$domainRole.ps1" 2>&1

    Write-Output $execResult

    $domainEnd = Get-Date
    $domainDuration = $domainEnd - $domainStart
    Write-Output "Domain $domainRole completed in $($domainDuration.ToString('mm\:ss'))"

    # Retrieve reports
    $remoteReportDir = "C:\MaesterReports\lab-run"
    $localDomainDir = "$EvidenceDir/$domainRole"
    New-Item -ItemType Directory -Force -Path $localDomainDir | Out-Null

    sshpass -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        "$sshTarget`:$remoteReportDir\$domainRole*" $localDomainDir/ 2>$null

    # Parse JSON summary if available
    $jsonFile = Get-ChildItem $localDomainDir -Filter "*.json" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($jsonFile) {
        $json = Get-Content $jsonFile -Raw | ConvertFrom-Json
        $testResults += [PSCustomObject]@{
            Domain      = $dc.domain
            Role        = $domainRole
            Total       = $json.TotalCount
            Passed      = $json.PassedCount
            Failed      = $json.FailedCount
            Investigate = $json.InvestigateCount
            Skipped     = $json.SkippedCount
            Error       = $json.ErrorCount
            Duration    = $json.TotalDuration
        }
        Write-Output "Results: $($json.PassedCount) Passed, $($json.FailedCount) Failed, $($json.InvestigateCount) Investigate, $($json.SkippedCount) Skipped"
    } else {
        Write-Warning "No JSON report retrieved for $domainRole — the test may have timed out or failed before generating output."
        Write-Warning "Troubleshooting: Check if the SSH session timed out. Run with -Domains $domainRole to test this domain individually."
    }

    Remove-Item $remoteScriptPath -ErrorAction SilentlyContinue
}

# --- Summary ---
$overallEnd = Get-Date
$overallDuration = $overallEnd - $overallStart

Write-Output ""
Write-Output "========================================"
Write-Output "LAB TEST RUN COMPLETE"
Write-Output "Total duration: $($overallDuration.ToString('hh\:mm\:ss'))"
Write-Output "========================================"

$testResults | Format-Table -AutoSize

$summaryFile = "$EvidenceDir/summary.json"
$testResults | ConvertTo-Json -Depth 3 | Set-Content $summaryFile

Write-Output "Evidence saved to: $EvidenceDir"
Write-Output "Summary saved to: $summaryFile"

if ($testResults.Count -lt $Domains.Count) {
    Write-Warning "Only $($testResults.Count) of $($Domains.Count) domains produced results."
    Write-Warning "This usually means the SSH session timed out during test execution."
    Write-Warning "Re-run with -Domains <Role> to test individual domains with shorter runtime."
}

# Clean up env
Remove-Item Env:SSHPASS -ErrorAction SilentlyContinue

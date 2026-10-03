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

.PARAMETER LabConfigPath
    Path to LabConfig.json. Defaults to ./build/activeDirectory/azure-lab/LabConfig.json

.PARAMETER EvidenceDir
    Local directory to store retrieved reports. Defaults to ./.sisyphus/evidence/lab-run-$(Get-Date -Format yyyyMMdd-HHmmss)

.PARAMETER SkipBuild
    Skip building the module. Use this if you have already built and want to re-run tests.

.PARAMETER Domains
    Which domains to test. Defaults to all domains in LabConfig. Options: RootForest, ChildDomain, SeparateForest.

.PARAMETER Tag
    Test tag filter. Defaults to "AD".

.EXAMPLE
    ./Run-LabADTests.ps1
    Builds module, runs AD tests against all domains, retrieves reports.

.EXAMPLE
    ./Run-LabADTests.ps1 -Domains RootForest -SkipBuild
    Re-runs tests against root domain only without rebuilding.
#>
[CmdletBinding()]
param(
    [string]$LabConfigPath = "$PSScriptRoot/LabConfig.json",
    [string]$EvidenceDir = "$PSScriptRoot/../../.sisyphus/evidence/lab-run-$(Get-Date -Format yyyyMMdd-HHmmss)",
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

Write-Host "Lab: $($lab.deployment.labPrefix) in $resourceGroup" -ForegroundColor Cyan
Write-Host "Windows runner: $($winRunner.azureVmName) at $($winRunner.publicIp)" -ForegroundColor Cyan
Write-Host "Key Vault: $keyVault" -ForegroundColor Cyan
Write-Host "Domains to test: $($Domains -join ', ')" -ForegroundColor Cyan
Write-Host "Evidence dir: $EvidenceDir" -ForegroundColor Cyan

# --- Ensure Azure login ---
$azAccount = az account show 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    Write-Host "Logging in to Azure with managed identity..." -ForegroundColor Yellow
    az login --identity | Out-Null
} else {
    Write-Host "Already logged in as: $($azAccount.user.name)" -ForegroundColor Green
}

# --- Build module ---
if (-not $SkipBuild) {
    Write-Host "`nBuilding Maester module..." -ForegroundColor Cyan
    $buildScript = "$PSScriptRoot/../../build/Build-LocalMaester.ps1"
    if (-not (Test-Path $buildScript)) {
        throw "Build script not found: $buildScript"
    }
    & $buildScript
    if ($LASTEXITCODE -ne 0) {
        throw "Module build failed."
    }
    Write-Host "Module built successfully." -ForegroundColor Green
} else {
    Write-Host "`nSkipping module build (using existing)." -ForegroundColor Yellow
}

# --- Retrieve secrets ---
Write-Host "`nRetrieving credentials from Key Vault..." -ForegroundColor Cyan

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

try { $childReaderPassword = Get-KvSecret -Name $lab.credentials.secretNames.childDomainReaderPassword } catch { }
try { $forestReaderPassword = Get-KvSecret -Name $lab.credentials.secretNames.forestDomainReaderPassword } catch { }

Write-Host "Credentials retrieved." -ForegroundColor Green

# --- Copy module to runner ---
Write-Host "`nCopying module to Windows runner..." -ForegroundColor Cyan
$moduleSource = "$PSScriptRoot/../../module"
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
Write-Host "Module copied to C:\MaesterDev on runner." -ForegroundColor Green

# --- Run tests per domain ---
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

$testResults = @()

foreach ($domainRole in $Domains) {
    $dc = $lab.domainControllers | Where-Object { $_.role -eq $domainRole }
    if (-not $dc) {
        Write-Warning "No DC found for role: $domainRole"
        continue
    }

    Write-Host "`nTesting domain: $($dc.domain) ($domainRole) via $($dc.fqdn) ..." -ForegroundColor Cyan

    $passwordToUse = $readerPassword
    if ($domainRole -eq 'ChildDomain') { $passwordToUse = $childReaderPassword }
    if ($domainRole -eq 'SeparateForest') { $passwordToUse = $forestReaderPassword }

    $remoteScript = @"
`$ErrorActionPreference = 'Stop'
Import-Module C:\MaesterDev\Maester.psd1 -Force
`$cred = [PSCredential]::new('$($dc.domain)\$($lab.credentials.testUserName)', (ConvertTo-SecureString '$passwordToUse' -AsPlainText -Force))
Connect-Maester -Service ActiveDirectory -ActiveDirectoryCredential `$cred `
  -ActiveDirectoryServer '$($dc.fqdn)' -ActiveDirectoryDomain '$($dc.domain)' `
  -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode Ldaps
`$reportDir = 'C:\MaesterReports\lab-run'
New-Item -ItemType Directory -Force -Path `$reportDir | Out-Null
Invoke-Maester -Path C:\MaesterTests\ad -Tag $Tag -NonInteractive -SkipGraphConnect `
  -OutputFolder `$reportDir -OutputFolderFileName '$domainRole'
Write-Output 'DONE'
"@

    $remoteScriptPath = "/tmp/run-$domainRole-$(Get-Random).ps1"
    $remoteScript | Set-Content $remoteScriptPath

    # Copy script to runner
    sshpass -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        $remoteScriptPath "$sshTarget`:C:\tmp\run-$domainRole.ps1" 2>$null

    # Execute
    $execResult = sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        $sshTarget "pwsh -ExecutionPolicy Bypass -File C:\tmp\run-$domainRole.ps1" 2>&1

    Write-Host $execResult -ForegroundColor Gray

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
        Write-Host "Results: $($json.PassedCount) Passed, $($json.FailedCount) Failed, $($json.InvestigateCount) Investigate, $($json.SkippedCount) Skipped" -ForegroundColor Green
    } else {
        Write-Warning "No JSON report retrieved for $domainRole"
    }

    Remove-Item $remoteScriptPath -ErrorAction SilentlyContinue
}

# --- Summary ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "LAB TEST RUN COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$testResults | Format-Table -AutoSize

$summaryFile = "$EvidenceDir/summary.json"
$testResults | ConvertTo-Json -Depth 3 | Set-Content $summaryFile

Write-Host "Evidence saved to: $EvidenceDir" -ForegroundColor Green
Write-Host "Summary saved to: $summaryFile" -ForegroundColor Green

# Clean up env
Remove-Item Env:SSHPASS -ErrorAction SilentlyContinue

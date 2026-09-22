[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Runner script provides status output.'
)]
[CmdletBinding()]
param(
    [Parameter()]
    [switch]$ConnectActiveDirectory,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetName,

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [ValidateSet('Negotiate', 'Kerberos', 'Ntlm', 'Basic')]
    [string]$AuthMode = 'Negotiate',

    [Parameter()]
    [ValidateSet('Auto', 'Ldaps', 'StartTls')]
    [string]$TlsMode = 'Auto',

    [Parameter()]
    [string]$MaesterModulePath = (Join-Path $PSScriptRoot "..\..\powershell"),

    [Parameter()]
    [string]$TestPath = (Join-Path $PSScriptRoot "..\..\tests"),

    [Parameter()]
    [string]$OutputFolder = (Join-Path $PSScriptRoot "..\..\test-results"),

    [Parameter()]
    [string]$TargetFolder = $PSScriptRoot,

    [Parameter()]
    [switch]$ExportCsv,

    [Parameter()]
    [switch]$ExportExcel
)

if (-not $ConnectActiveDirectory.IsPresent) {
    throw 'Active Directory testing is opt-in. Re-run with -ConnectActiveDirectory to explicitly connect to Active Directory and run AD tests.'
}

$ErrorActionPreference = 'Stop'
$startTime = Get-Date

Write-Host '=== Maester Active Directory Test Runner (Single Target) ===' -ForegroundColor Cyan
Write-Host "Start Time: $startTime" -ForegroundColor Gray
Write-Host "TargetName: $TargetName" -ForegroundColor Gray
Write-Host "Requested authentication mode: $AuthMode" -ForegroundColor Gray
Write-Host "Requested TLS mode: $TlsMode" -ForegroundColor Gray
Write-Host "Credential mode: $(if ($null -eq $Credential) { 'Implicit' } else { 'Explicit' })" -ForegroundColor Gray
Write-Host ''

# Invoke the canonical prerequisite check before any tests run.
$prereqScript = Join-Path (Join-Path $PSScriptRoot 'azure-lab') 'Test-ADProtocolPrerequisites.ps1'
if (-not (Test-Path $prereqScript)) {
    throw "Prerequisite script not found at: $prereqScript"
}

Write-Host 'Running protocol prerequisite check...' -ForegroundColor Yellow
$prereqParams = @{
    TargetName         = $TargetName
    MaesterModulePath  = $MaesterModulePath
}
$prereqResult = & $prereqScript @prereqParams

if (-not $prereqResult.IsReady) {
    throw "Prerequisite check failed for '$TargetName'. Run '$prereqScript -TargetName $TargetName' for details."
}

Write-Host 'Prerequisite check passed.' -ForegroundColor Green
Write-Host ''

Write-Host 'Single-target rule:' -ForegroundColor Yellow
Write-Host '  This script runs one isolated endpoint per Connect-Maester / Invoke-Maester cycle.' -ForegroundColor Yellow
Write-Host ''

# Resolve paths
$MaesterModulePath = Resolve-Path $MaesterModulePath -ErrorAction Stop
$TestPath = Resolve-Path $TestPath -ErrorAction Stop

if (-not (Test-Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}
$OutputFolder = Resolve-Path $OutputFolder -ErrorAction Stop

if (-not (Test-Path $TargetFolder)) {
    New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
}
$TargetFolder = Resolve-Path $TargetFolder -ErrorAction Stop

# Import Maester module
$manifestPath = Join-Path $MaesterModulePath 'Maester.psd1'
if (-not (Test-Path $manifestPath)) {
    throw "Maester module manifest not found at: $manifestPath"
}

Import-Module $manifestPath -Force

# Validate the explicit Active Directory connection before any tests run.
Write-Host 'Validating Active Directory connection...' -ForegroundColor Yellow
Connect-Maester -Service ActiveDirectory -ActiveDirectoryServer $TargetName -ActiveDirectoryCredential $Credential -ActiveDirectoryAuthMode $AuthMode -ActiveDirectoryTlsMode $TlsMode | Out-Null

$connectionDetails = Test-MtConnection -Service ActiveDirectory -Details
$adConnection = $connectionDetails.ActiveDirectory
if (-not $connectionDetails.AllConnected -or -not $adConnection.ProtocolValidated) {
    throw 'The certified Active Directory protocol path did not complete successfully.'
}

$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$publicPathEvidence = [ordered]@{
    SchemaVersion       = 1
    RecordedAt          = (Get-Date).ToUniversalTime().ToString('o')
    ProtocolValidated   = [bool]$adConnection.ProtocolValidated
    ProtocolPath        = $adConnection.ProtocolPath
    Targeting           = [ordered]@{
        RequestedTarget = $TargetName
        ResolvedServer  = $adConnection.ResolvedServer
        ResolvedDomain  = $adConnection.ResolvedDomain
        ResolvedForest  = $adConnection.ResolvedForest
    }
    Authentication      = [ordered]@{
        RequestedMode   = $AuthMode
        SelectedMode    = $adConnection.AuthenticationMode
        CredentialMode  = if ($null -eq $Credential) { 'Implicit' } else { 'Explicit' }
        CredentialUser  = if ($null -eq $Credential) { $null } else { $Credential.UserName }
    }
    Transport           = [ordered]@{
        RequestedTlsMode = $TlsMode
        SelectedTlsMode  = $adConnection.TlsMode
    }
}
$evidenceFile = Join-Path $TargetFolder "AD-PublicPath-$TargetName-$timestamp.json"
$publicPathEvidence | ConvertTo-Json -Depth 6 | Set-Content -Path $evidenceFile -Encoding utf8
Write-Host "Protocol evidence: $evidenceFile" -ForegroundColor Green

# Verify AD tests paths
$adTestPaths = @(
    (Join-Path $TestPath 'Maester\ad'),
    (Join-Path $TestPath 'ad')
)
$validTestPaths = @($adTestPaths | Where-Object { Test-Path $_ })
if (-not $validTestPaths -or $validTestPaths.Count -eq 0) {
    throw "No AD test paths found under: $TestPath"
}

Write-Host 'Running Maester AD tests (Tag: AD) and generating reports...' -ForegroundColor Yellow
$outputPrefix = "AD-TestResults-$TargetName-$timestamp"

$invokeParams = @{
    Path = $validTestPaths[0]
    Tag = 'AD'
    OutputFolder = $OutputFolder
    OutputFolderFileName = $outputPrefix
    NonInteractive = $true
    SkipGraphConnect = $true
    PassThru = $true
}

if ($ExportCsv.IsPresent) {
    $invokeParams.ExportCsv = $true
}

if ($ExportExcel.IsPresent) {
    $invokeParams.ExportExcel = $true
}

$results = Invoke-Maester @invokeParams

# Copy reports
Write-Host "Copying generated reports to: $TargetFolder" -ForegroundColor Yellow

$patterns = @(
    "$outputPrefix*.html",
    "$outputPrefix*.md",
    "$outputPrefix*.json"
)

if ($ExportCsv.IsPresent) {
    $patterns += "$outputPrefix*.csv"
}

if ($ExportExcel.IsPresent) {
    $patterns += "$outputPrefix*.xlsx"
}

$copiedFiles = @()
foreach ($pattern in $patterns) {
    $files = Get-ChildItem -Path $OutputFolder -Filter $pattern -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        Copy-Item -Path $file.FullName -Destination (Join-Path $TargetFolder $file.Name) -Force
        $copiedFiles += (Join-Path $TargetFolder $file.Name)
        Write-Host "  Copied: $($file.Name)" -ForegroundColor Green
    }
}

if ($copiedFiles.Count -eq 0) {
    Write-Warning "No reports were copied. Ensure Invoke-Maester generated output files with prefix '$outputPrefix'."
}

$endTime = Get-Date
Write-Host ''
Write-Host '=== Execution Summary ===' -ForegroundColor Cyan
Write-Host "Duration: $($endTime - $startTime)" -ForegroundColor Gray
Write-Host "Reports saved to: $TargetFolder" -ForegroundColor Gray
Write-Host "Report prefix: $outputPrefix" -ForegroundColor Gray
Write-Host "Results returned: $(@($results).Count)" -ForegroundColor Gray

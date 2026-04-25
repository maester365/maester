# Phase 19 GPO State Validation Script
# This script validates all 27 GPO State test functions against the live DC

$ErrorActionPreference = "Stop"
$results = @()

Write-Host "=== Phase 19 GPO State Validation ===" -ForegroundColor Cyan
Write-Host "Domain: $env:USERDNSDOMAIN"
Write-Host "DC: $env:COMPUTERNAME"
Write-Host "Date: $(Get-Date)`n"

# Import required modules
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
Import-Module GroupPolicy -ErrorAction SilentlyContinue

# Source the functions
$functionPath = "/tmp/maester-powershell/public"
Get-ChildItem "$functionPath" -Recurse -Filter "*.ps1" | ForEach-Object { 
    try {
        . $_.FullName
    } catch {
        Write-Warning "Failed to load $($_.Name): $_"
    }
}

# Test Get-MtADGpoState
Write-Host "Testing Get-MtADGpoState..." -NoNewline
$testResult = @{ TestName = "Get-MtADGpoState"; TestID = "N/A"; Result = "FAIL"; Details = "" }
try {
    $gpoState = Get-MtADGpoState
    if ($gpoState -and $gpoState.GPOs) {
        Write-Host " PASS" -ForegroundColor Green
        $testResult.Result = "PASS"
        $testResult.Details = "Found $($gpoState.GPOs.Count) GPOs, $($gpoState.GPOReports.Count) reports"
        Write-Host "  GPOs: $($gpoState.GPOs.Count)"
        Write-Host "  GPO Reports: $($gpoState.GPOReports.Count)"
    } else {
        Write-Host " FAIL (no data)" -ForegroundColor Red
        $testResult.Details = "No GPO data returned"
    }
} catch {
    Write-Host " FAIL ($_))" -ForegroundColor Red
    $testResult.Details = "Error: $_"
}
$results += $testResult

# Test functions to validate
$tests = @(
    @{ Name = "Test-MtAdGpoStateTotalCount"; ID = "AD-GPOS-01" },
    @{ Name = "Test-MtAdGpoWmiFilterCount"; ID = "AD-GPOS-02" },
    @{ Name = "Test-MtAdGpoWmiFilterDetails"; ID = "AD-GPOS-03" },
    @{ Name = "Test-MtAdGpoSettingsDisabledCount"; ID = "AD-GPOS-04" },
    @{ Name = "Test-MtAdGpoComputerSettingsDisabledDetails"; ID = "AD-GPOS-05" },
    @{ Name = "Test-MtAdGpoUserSettingsDisabledDetails"; ID = "AD-GPOS-06" },
    @{ Name = "Test-MtAdGpoAllSettingsDisabledDetails"; ID = "AD-GPOS-07" },
    @{ Name = "Test-MtAdGpoOwnerDistinctCount"; ID = "AD-GPOS-08" },
    @{ Name = "Test-MtAdGpoOwnerDetails"; ID = "AD-GPOS-09" },
    @{ Name = "Test-MtAdGpoNoPermissionsCount"; ID = "AD-GPOREP-01" },
    @{ Name = "Test-MtAdGpoNoPermissionsDetails"; ID = "AD-GPOREP-02" },
    @{ Name = "Test-MtAdGpoNoAuthenticatedUsersCount"; ID = "AD-GPOREP-03" },
    @{ Name = "Test-MtAdGpoNoAuthenticatedUsersDetails"; ID = "AD-GPOREP-04" },
    @{ Name = "Test-MtAdGpoNoEnterpriseDcCount"; ID = "AD-GPOREP-05" },
    @{ Name = "Test-MtAdGpoNoDomainComputersCount"; ID = "AD-GPOREP-06" },
    @{ Name = "Test-MtAdGpoDenyAceCount"; ID = "AD-GPOREP-07" },
    @{ Name = "Test-MtAdGpoDenyAceDetails"; ID = "AD-GPOREP-08" },
    @{ Name = "Test-MtAdGpoInheritedPermissionsCount"; ID = "AD-GPOREP-09" },
    @{ Name = "Test-MtAdGpoNoApplyGroupPolicyAceCount"; ID = "AD-GPOREP-10" },
    @{ Name = "Test-MtAdGpoNoApplyGroupPolicyAceDetails"; ID = "AD-GPOREP-11" },
    @{ Name = "Test-MtAdGpoDisabledLinkCount"; ID = "AD-GPOREP-12" },
    @{ Name = "Test-MtAdGpoDisabledLinkDetails"; ID = "AD-GPOREP-13" },
    @{ Name = "Test-MtAdGpoEnforcementCount"; ID = "AD-GPOREP-14" },
    @{ Name = "Test-MtAdGpoVersionMismatchCount"; ID = "AD-GPOREP-15" },
    @{ Name = "Test-MtAdGpoVersionMismatchDetails"; ID = "AD-GPOREP-16" },
    @{ Name = "Test-MtAdGpoCpasswordFoundCount"; ID = "AD-GPOREP-17" },
    @{ Name = "Test-MtAdGpoCpasswordFoundDetails"; ID = "AD-GPOREP-18" },
    @{ Name = "Test-MtAdGpoDefaultPasswordFoundCount"; ID = "AD-GPOREP-19" },
    @{ Name = "Test-MtAdGpoDefaultPasswordFoundDetails"; ID = "AD-GPOREP-20" }
)

foreach ($test in $tests) {
    Write-Host "Testing $($test.Name)..." -NoNewline
    $testResult = @{ TestName = $test.Name; TestID = $test.ID; Result = "FAIL"; Details = "" }
    
    try {
        $result = & $test.Name
        if ($result -eq $true) {
            Write-Host " PASS" -ForegroundColor Green
            $testResult.Result = "PASS"
        } elseif ($result -eq $null) {
            Write-Host " SKIP (no AD connection)" -ForegroundColor Yellow
            $testResult.Result = "SKIP"
            $testResult.Details = "Returned null - AD not connected"
        } else {
            Write-Host " FAIL (returned $result)" -ForegroundColor Red
            $testResult.Details = "Returned $result"
        }
    } catch {
        Write-Host " FAIL ($_))" -ForegroundColor Red
        $testResult.Details = "Error: $_"
    }
    
    $results += $testResult
}

# Summary
Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan
$passCount = ($results | Where-Object { $_.Result -eq "PASS" }).Count
$skipCount = ($results | Where-Object { $_.Result -eq "SKIP" }).Count
$failCount = ($results | Where-Object { $_.Result -eq "FAIL" }).Count

Write-Host "Total Tests: $($results.Count)"
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Skipped: $skipCount" -ForegroundColor Yellow
Write-Host "Failed: $failCount" -ForegroundColor Red

# Export results
$results | Export-Csv "/tmp/Phase19-ValidationResults.csv" -NoTypeInformation
Write-Host "`nResults exported to: /tmp/Phase19-ValidationResults.csv"

if ($failCount -eq 0) {
    Write-Host "`n✓ All tests passed validation!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some tests failed validation" -ForegroundColor Red
    exit 1
}

# Simple Phase 19 Validation Script
# Run this on the domain controller to verify GPO State tests

param(
    [switch]$Quick,
    [switch]$Detailed
)

Write-Host "=== Phase 19 GPO State Simple Validation ===" -ForegroundColor Cyan

# Check if we're on a domain controller
if (-not (Get-Module ActiveDirectory -ListAvailable)) {
    Write-Error "Active Directory module not available. Run on a domain controller."
    exit 1
}

# Import Maester module
$modulePath = "C:\Program Files\WindowsPowerShell\Modules\Maester"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    # Try to import from local path
    $localPath = ".\powershell\Maester.psd1"
    if (Test-Path $localPath) {
        Import-Module $localPath -Force
    } else {
        Write-Warning "Maester module not found. Functions must be dot-sourced manually."
    }
}

# Quick validation - just test Get-MtADGpoState
if ($Quick) {
    Write-Host "`nRunning quick validation..." -ForegroundColor Yellow
    try {
        $gpoState = Get-MtADGpoState
        if ($gpoState -and $gpoState.GPOs) {
            Write-Host "✓ Get-MtADGpoState: SUCCESS" -ForegroundColor Green
            Write-Host "  Found $($gpoState.GPOs.Count) GPOs"
            Write-Host "  Found $($gpoState.GPOReports.Count) GPO reports"
            exit 0
        } else {
            Write-Host "✗ Get-MtADGpoState: FAILED (no data)" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "✗ Get-MtADGpoState: FAILED ($_))" -ForegroundColor Red
        exit 1
    }
}

# Full validation
Write-Host "`nRunning full validation..." -ForegroundColor Yellow

$tests = @(
    @{ Name = "Get-MtADGpoState"; ID = "SETUP"; Category = "Setup" },
    @{ Name = "Test-MtAdGpoStateTotalCount"; ID = "AD-GPOS-01"; Category = "GPO State" },
    @{ Name = "Test-MtAdGpoWmiFilterCount"; ID = "AD-GPOS-02"; Category = "GPO State" },
    @{ Name = "Test-MtAdGpoSettingsDisabledCount"; ID = "AD-GPOS-04"; Category = "GPO State" },
    @{ Name = "Test-MtAdGpoOwnerDistinctCount"; ID = "AD-GPOS-08"; Category = "GPO State" },
    @{ Name = "Test-MtAdGpoNoPermissionsCount"; ID = "AD-GPOREP-01"; Category = "GPO Reports" },
    @{ Name = "Test-MtAdGpoNoAuthenticatedUsersCount"; ID = "AD-GPOREP-03"; Category = "GPO Reports" },
    @{ Name = "Test-MtAdGpoDenyAceCount"; ID = "AD-GPOREP-07"; Category = "GPO Reports" },
    @{ Name = "Test-MtAdGpoDisabledLinkCount"; ID = "AD-GPOREP-12"; Category = "GPO Reports" },
    @{ Name = "Test-MtAdGpoVersionMismatchCount"; ID = "AD-GPOREP-15"; Category = "GPO Reports" },
    @{ Name = "Test-MtAdGpoCpasswordFoundCount"; ID = "AD-GPOREP-17"; Category = "GPO Reports" }
)

$results = @()
$passed = 0
$failed = 0

foreach ($test in $tests) {
    Write-Host "Testing $($test.Name) [$($test.ID)]..." -NoNewline
    
    try {
        if ($test.Name -eq "Get-MtADGpoState") {
            $result = Get-MtADGpoState
            $success = ($null -ne $result -and $result.GPOs)
        } else {
            $result = & $test.Name
            $success = ($result -eq $true)
        }
        
        if ($success) {
            Write-Host " PASS" -ForegroundColor Green
            $passed++
            $results += [PSCustomObject]@{ Test = $test.Name; ID = $test.ID; Result = "PASS" }
        } else {
            Write-Host " FAIL (returned $result)" -ForegroundColor Red
            $failed++
            $results += [PSCustomObject]@{ Test = $test.Name; ID = $test.ID; Result = "FAIL" }
        }
    } catch {
        Write-Host " ERROR ($_))" -ForegroundColor Red
        $failed++
        $results += [PSCustomObject]@{ Test = $test.Name; ID = $test.ID; Result = "ERROR"; Message = $_ }
    }
}

# Summary
Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Total:  $($passed + $failed)"

if ($Detailed) {
    Write-Host "`nDetailed Results:" -ForegroundColor Yellow
    $results | Format-Table -AutoSize
}

# Export results
$results | Export-Csv "C:\temp\Phase19-Validation.csv" -NoTypeInformation
Write-Host "`nResults saved to: C:\temp\Phase19-Validation.csv"

if ($failed -eq 0) {
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some tests failed" -ForegroundColor Red
    exit 1
}

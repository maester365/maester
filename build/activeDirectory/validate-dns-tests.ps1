# DNS Tests Validation Script
# This script validates all 19 Phase 4 DNS tests against the live domain controller

$ErrorActionPreference = "Continue"
$results = @()

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Phase 4: DNS Infrastructure Validation" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Import the Maester module
Import-Module ActiveDirectory
Import-Module DnsServer
Import-Module /tmp/maester-powershell/Maester.psd1 -Force

# List of all DNS test functions
$dnsTests = @(
    "Test-MtAdDnsZoneCount",
    "Test-MtAdDnsZonesWithOnlySoaNs",
    "Test-MtAdDnsRootServerIncorrectCount",
    "Test-MtAdDnsRootServerIncorrectDetails",
    "Test-MtAdDnsDynamicRecordCount",
    "Test-MtAdDnsZonesWithRecordsCount",
    "Test-MtAdDnsZoneRecordDetails",
    "Test-MtAdDnsZoneDelegationCount",
    "Test-MtAdDnsZoneDelegationDetails",
    "Test-MtAdDnsSoaDetails",
    "Test-MtAdDnsAdSrvRecordCount",
    "Test-MtAdDnsAdSrvRecordDetails",
    "Test-MtAdDnsDnssecRecordCount",
    "Test-MtAdDnsEmptyZoneCount",
    "Test-MtAdDnsDuplicateZoneCount",
    "Test-MtAdDnsReverseZoneCount",
    "Test-MtAdDnsNonStandardZoneCount",
    "Test-MtAdDnsReverseZoneNetworkCount",
    "Test-MtAdDnsReverseZoneNetworkDetails"
)

$passed = 0
$failed = 0
$skipped = 0

foreach ($testName in $dnsTests) {
    Write-Host "Testing: $testName" -NoNewline
    
    try {
        $result = & $testName -ErrorAction Stop
        
        if ($null -eq $result) {
            Write-Host " [SKIPPED]" -ForegroundColor Yellow
            $skipped++
            $results += [PSCustomObject]@{
                TestName = $testName
                Result = "SKIPPED"
                ReturnValue = $null
                Error = "Test returned null (AD not connected or data unavailable)"
            }
        } elseif ($result -eq $true) {
            Write-Host " [PASS]" -ForegroundColor Green
            $passed++
            $results += [PSCustomObject]@{
                TestName = $testName
                Result = "PASS"
                ReturnValue = $result
                Error = $null
            }
        } else {
            Write-Host " [FAIL]" -ForegroundColor Red
            $failed++
            $results += [PSCustomObject]@{
                TestName = $testName
                Result = "FAIL"
                ReturnValue = $result
                Error = "Test returned false"
            }
        }
    } catch {
        Write-Host " [ERROR]" -ForegroundColor Red
        $failed++
        $results += [PSCustomObject]@{
            TestName = $testName
            Result = "ERROR"
            ReturnValue = $null
            Error = $_.Exception.Message
        }
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Total Tests:  $($dnsTests.Count)" -ForegroundColor White
Write-Host "Passed:       $passed" -ForegroundColor Green
Write-Host "Failed:       $failed" -ForegroundColor Red
Write-Host "Skipped:      $skipped" -ForegroundColor Yellow
Write-Host ""

if ($failed -eq 0) {
    Write-Host "VALIDATION SUCCESSFUL - All tests passed!" -ForegroundColor Green
} else {
    Write-Host "VALIDATION FAILED - $failed tests failed or had errors" -ForegroundColor Red
}

# Output detailed results
Write-Host ""
Write-Host "Detailed Results:" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# Export results to file
$results | Export-Csv -Path "/tmp/dns-validation-results.csv" -NoTypeInformation
Write-Host "Results exported to: /tmp/dns-validation-results.csv" -ForegroundColor Cyan

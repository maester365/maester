#Requires -Module ActiveDirectory, GroupPolicy
param()
$ErrorActionPreference = 'Stop'

Write-Host "Phase 7 GPO Test Validation" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Green

# Test Get-GPO
Write-Host "`nTest: Get-GPO Availability" -ForegroundColor Yellow
try {
    $gpos = Get-GPO -All
    Write-Host "  PASS: Found $($gpos.Count) GPOs" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
    exit 1
}

# Test Get-ADOrganizationalUnit
Write-Host "`nTest: Get-ADOrganizationalUnit Availability" -ForegroundColor Yellow
try {
    $ous = Get-ADOrganizationalUnit -Filter * -Properties gPLink, gpOptions
    Write-Host "  PASS: Found $($ous.Count) OUs" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
    exit 1
}

# Test GPO Date Filtering
Write-Host "`nTest: GPO Date Filtering" -ForegroundColor Yellow
try {
    $cutoffDate = Get-Date -Year 2020 -Month 1 -Day 1
    $oldGpos = $gpos | Where-Object { $_.CreationTime -lt $cutoffDate }
    Write-Host "  PASS: Found $($oldGpos.Count) GPOs created before 2020" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
}

# Test GPO Link Parsing
Write-Host "`nTest: GPO Link Parsing" -ForegroundColor Yellow
try {
    $linkedOUs = $ous | Where-Object { $_.gPLink -and $_.gPLink -ne '' }
    Write-Host "  PASS: Found $($linkedOUs.Count) OUs with GPO links" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
}

# Test Blocked Inheritance
Write-Host "`nTest: Blocked Inheritance Detection" -ForegroundColor Yellow
try {
    $blockedOUs = $ous | Where-Object { $_.gpOptions -eq 1 }
    Write-Host "  PASS: Found $($blockedOUs.Count) OUs with blocked inheritance" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
}

Write-Host "`n===========================" -ForegroundColor Green
Write-Host "Validation Complete!" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Green

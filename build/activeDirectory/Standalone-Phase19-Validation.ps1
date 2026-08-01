# Standalone Phase 19 Validation (No Module Dependencies)
# Run this on the DC to validate GPO State functionality

Write-Host "=== Phase 19 GPO State Standalone Validation ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray
Write-Host "DC: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host ""

# Import required Windows modules
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

Write-Host "[OK] Modules loaded (ActiveDirectory, GroupPolicy)" -ForegroundColor Green

# Test 1: Basic GPO Access
Write-Host "`n[Test 1] Get-GPO -All..." -NoNewline
try {
    $gpos = Get-GPO -All
    Write-Host " PASS" -ForegroundColor Green
    Write-Host "  Found $($gpos.Count) GPOs" -ForegroundColor Gray
    $test1 = $true
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    $test1 = $false
}

# Test 2: GPO Report Generation
Write-Host "`n[Test 2] Get-GPOReport..." -NoNewline
try {
    $gpo = $gpos | Select-Object -First 1
    $report = Get-GPOReport -Guid $gpo.Id -ReportType Xml
    $xml = [xml]$report
    Write-Host " PASS" -ForegroundColor Green
    Write-Host "  GPO Name: $($xml.GPO.Name)" -ForegroundColor Gray
    $test2 = $true
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    $test2 = $false
}

# Test 3: Parse GPO Permissions
Write-Host "`n[Test 3] Parse GPO Permissions..." -NoNewline
try {
    $trusteeNames = $xml.GPO.SecurityDescriptor.Permissions.TrusteePermissions | ForEach-Object { $_.Trustee.Name.'#text' }
    $hasAuthUsers = $trusteeNames -contains "NT AUTHORITY\Authenticated Users"
    Write-Host " PASS" -ForegroundColor Green
    Write-Host "  Trustees: $($trusteeNames.Count)" -ForegroundColor Gray
    Write-Host "  Has Authenticated Users: $hasAuthUsers" -ForegroundColor Gray
    $test3 = $true
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    $test3 = $false
}

# Test 4: Parse GPO Links
Write-Host "`n[Test 4] Parse GPO Links..." -NoNewline
try {
    $links = $xml.GPO.LinksTo
    $disabledLinks = $links | Where-Object { $_.Enabled -eq $false }
    Write-Host " PASS" -ForegroundColor Green
    Write-Host "  Total Links: $($links.Count)" -ForegroundColor Gray
    Write-Host "  Disabled Links: $($disabledLinks.Count)" -ForegroundColor Gray
    $test4 = $true
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    $test4 = $false
}

# Test 5: Parse GPO Settings
Write-Host "`n[Test 5] Parse GPO Settings..." -NoNewline
try {
    $computerEnabled = $xml.GPO.Computer.Enabled -eq $true
    $userEnabled = $xml.GPO.User.Enabled -eq $true
    $compSettings = ($xml.GPO.Computer.ExtensionData | Measure-Object).Count
    $userSettings = ($xml.GPO.User.ExtensionData | Measure-Object).Count
    Write-Host " PASS" -ForegroundColor Green
    Write-Host "  Computer: Enabled=$computerEnabled, Settings=$compSettings" -ForegroundColor Gray
    Write-Host "  User: Enabled=$userEnabled, Settings=$userSettings" -ForegroundColor Gray
    $test5 = $true
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    $test5 = $false
}

# Test 6: Check for Cpassword
Write-Host "`n[Test 6] Check for Cpassword/DefaultPassword..." -NoNewline
try {
    $hasCpassword = $report -like "*Cpassword*"
    $hasDefaultPassword = $report -like "*DefaultPassword*"
    Write-Host " PASS" -ForegroundColor Green
    Write-Host "  Cpassword Found: $hasCpassword" -ForegroundColor Gray
    Write-Host "  DefaultPassword Found: $hasDefaultPassword" -ForegroundColor Gray
    $test6 = $true
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    $test6 = $false
}

# Test 7: Version Check
Write-Host "`n[Test 7] Check GPO Versions..." -NoNewline
try {
    $compDirVer = $xml.GPO.Computer.VersionDirectory
    $compSysVer = $xml.GPO.Computer.VersionSysvol
    $userDirVer = $xml.GPO.User.VersionDirectory
    $userSysVer = $xml.GPO.User.VersionSysvol
    $versionMismatch = ($compDirVer -ne $compSysVer) -or ($userDirVer -ne $userSysVer)
    Write-Host " PASS" -ForegroundColor Green
    Write-Host "  Computer: Dir=$compDirVer, Sysvol=$compSysVer" -ForegroundColor Gray
    Write-Host "  User: Dir=$userDirVer, Sysvol=$userSysVer" -ForegroundColor Gray
    Write-Host "  Mismatch: $versionMismatch" -ForegroundColor Gray
    $test7 = $true
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    $test7 = $false
}

# Summary
Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan
$passed = ($test1,$test2,$test3,$test4,$test5,$test6,$test7 | Where-Object { $_ -eq $true }).Count
$total = 7

Write-Host "Tests Passed: $passed / $total" -ForegroundColor $(if($passed -eq $total){'Green'}else{'Yellow'})

if ($passed -eq $total) {
    Write-Host "`n[SUCCESS] ALL VALIDATIONS PASSED!" -ForegroundColor Green
    Write-Host "The GPO State tests will work correctly on this DC." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠ Some tests failed" -ForegroundColor Yellow
    exit 1
}

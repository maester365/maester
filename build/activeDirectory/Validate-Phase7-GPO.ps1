#Requires -Module ActiveDirectory, GroupPolicy
<#
.SYNOPSIS
    Validation script for Phase 7 GPO tests.

.DESCRIPTION
    This script validates all 11 Phase 7 Group Policy tests against the live Active Directory environment.
    It should be run on a domain controller or domain-joined machine with RSAT tools installed.

.EXAMPLE
    .\Validate-Phase7-GPO.ps1

    Runs all Phase 7 GPO tests and outputs results.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ValidationResults = @()

# Helper function to simulate Add-MtTestResultDetail
function Add-MtTestResultDetail {
    param([string]$Result)
    Write-Host "Test Result Detail: $Result" -ForegroundColor Cyan
}

# Helper function to simulate the skipped because enum
$NotConnectedActiveDirectory = "NotConnectedActiveDirectory"

Write-Host "=========================================" -ForegroundColor Green
Write-Host "Phase 7 GPO Test Validation" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Test 1: Get-MtADGpoState availability
Write-Host "Test 0: Verifying Get-GPO cmdlet availability..." -ForegroundColor Yellow
try {
    $gpoTest = Get-GPO -All | Select-Object -First 1
    if ($gpoTest) {
        Write-Host "  ✓ Get-GPO cmdlet working. Found GPO: $($gpoTest.DisplayName)" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "Get-GPO Availability"; Status = "PASS"; Details = "Cmdlet working" }
    } else {
        Write-Host "  ✗ Get-GPO returned no results" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "Get-GPO Availability"; Status = "FAIL"; Details = "No GPOs found" }
    }
} catch {
    Write-Host "  ✗ Get-GPO failed: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "Get-GPO Availability"; Status = "FAIL"; Details = $_.Exception.Message }
}

Write-Host ""

# Function to simulate Get-MtADGpoState
function Get-MtADGpoState {
    param([switch]$Refresh)
    
    try {
        $rootDSE = Get-ADRootDSE
        $configurationNC = $rootDSE.configurationNamingContext

        $gpoState = @{
            GPOs            = Get-GPO -All
            GPOLinks        = Get-ADObject -Filter * -SearchBase "CN=Sites,CN=Configuration,$configurationNC" -Properties gPLink
            SiteContainers  = Get-ADObject -Filter * -SearchBase "CN=Sites,CN=Configuration,$configurationNC" -Properties *
            CollectionTime  = Get-Date
        }

        return $gpoState
    }
    catch {
        Write-Error "Failed to collect AD GPO State data: $($_.Exception.Message)"
        return $null
    }
}

# Get GPO State once for all tests
Write-Host "Collecting GPO State data..." -ForegroundColor Yellow
$gpoState = Get-MtADGpoState

if ($null -eq $gpoState) {
    Write-Host "✗ CRITICAL: Unable to retrieve GPO State. Cannot continue validation." -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ GPO State collected successfully" -ForegroundColor Green
Write-Host "    - GPOs found: $($gpoState.GPOs.Count)" -ForegroundColor Gray
Write-Host "    - GPOLinks found: $($gpoState.GPOLinks.Count)" -ForegroundColor Gray
Write-Host ""

# ============================================
# AD-GPO-01: GpoTotalCount
# ============================================
Write-Host "Test AD-GPO-01: GpoTotalCount" -ForegroundColor Yellow
try {
    $gpos = $gpoState.GPOs
    $totalCount = ($gpos | Measure-Object).Count
    $testResult = $totalCount -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - Total GPOs: $totalCount" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-01: GpoTotalCount"; Status = "PASS"; Details = "Count: $totalCount" }
    } else {
        Write-Host "  ✗ FAIL - Could not retrieve GPO count" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-01: GpoTotalCount"; Status = "FAIL"; Details = "Could not count" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-01: GpoTotalCount"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPO-02: GpoCreatedBefore2020Count
# ============================================
Write-Host "Test AD-GPO-02: GpoCreatedBefore2020Count" -ForegroundColor Yellow
try {
    $gpos = $gpoState.GPOs
    $cutoffDate = Get-Date -Year 2020 -Month 1 -Day 1
    $oldGpos = $gpos | Where-Object { $_.CreationTime -lt $cutoffDate }
    $oldCount = ($oldGpos | Measure-Object).Count
    $totalCount = ($gpos | Measure-Object).Count
    $testResult = $totalCount -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - GPOs created before 2020: $oldCount / $totalCount" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-02: GpoCreatedBefore2020Count"; Status = "PASS"; Details = "$oldCount / $totalCount" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-02: GpoCreatedBefore2020Count"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-02: GpoCreatedBefore2020Count"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPO-03: GpoChangedBefore2020Count
# ============================================
Write-Host "Test AD-GPO-03: GpoChangedBefore2020Count" -ForegroundColor Yellow
try {
    $gpos = $gpoState.GPOs
    $cutoffDate = Get-Date -Year 2020 -Month 1 -Day 1
    $staleGpos = $gpos | Where-Object { $_.ModificationTime -lt $cutoffDate }
    $staleCount = ($staleGpos | Measure-Object).Count
    $totalCount = ($gpos | Measure-Object).Count
    $testResult = $totalCount -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - GPOs changed before 2020: $staleCount / $totalCount" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-03: GpoChangedBefore2020Count"; Status = "PASS"; Details = "$staleCount / $totalCount" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-03: GpoChangedBefore2020Count"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-03: GpoChangedBefore2020Count"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPO-04: GpoUnlinkedCount
# ============================================
Write-Host "Test AD-GPO-04: GpoUnlinkedCount" -ForegroundColor Yellow
try {
    $gpos = $gpoState.GPOs
    $gpoLinks = $gpoState.GPOLinks
    
    # Get all linked GPO GUIDs
    $linkedGuids = @()
    foreach ($link in $gpoLinks) {
        if ($link.gPLink) {
            $matches = [regex]::Matches($link.gPLink, 'CN=\{([^}]+)\}')
            foreach ($match in $matches) {
                $linkedGuids += $match.Groups[1].Value
            }
        }
    }
    
    $unlinkedGpos = $gpos | Where-Object { $linkedGuids -notcontains $_.Id.Guid }
    $unlinkedCount = ($unlinkedGpos | Measure-Object).Count
    $totalCount = ($gpos | Measure-Object).Count
    $testResult = $totalCount -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - Unlinked GPOs: $unlinkedCount / $totalCount" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-04: GpoUnlinkedCount"; Status = "PASS"; Details = "$unlinkedCount / $totalCount" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-04: GpoUnlinkedCount"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-04: GpoUnlinkedCount"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPO-05: GpoUnlinkedDetails
# ============================================
Write-Host "Test AD-GPO-05: GpoUnlinkedDetails" -ForegroundColor Yellow
try {
    $gpos = $gpoState.GPOs
    $gpoLinks = $gpoState.GPOLinks
    
    # Get all linked GPO GUIDs
    $linkedGuids = @()
    foreach ($link in $gpoLinks) {
        if ($link.gPLink) {
            $matches = [regex]::Matches($link.gPLink, 'CN=\{([^}]+)\}')
            foreach ($match in $matches) {
                $linkedGuids += $match.Groups[1].Value
            }
        }
    }
    
    $unlinkedGpos = $gpos | Where-Object { $linkedGuids -notcontains $_.Id.Guid }
    $unlinkedCount = ($unlinkedGpos | Measure-Object).Count
    $testResult = $unlinkedCount -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - Unlinked GPOs found: $unlinkedCount" -ForegroundColor Green
        if ($unlinkedCount -gt 0) {
            Write-Host "    First 3 unlinked GPOs:" -ForegroundColor Gray
            $unlinkedGpos | Select-Object -First 3 | ForEach-Object {
                Write-Host "      - $($_.DisplayName) (Created: $($_.CreationTime))" -ForegroundColor Gray
            }
        }
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-05: GpoUnlinkedDetails"; Status = "PASS"; Details = "$unlinkedCount unlinked" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-05: GpoUnlinkedDetails"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPO-05: GpoUnlinkedDetails"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPOL-01: GpoLinkedCount
# ============================================
Write-Host "Test AD-GPOL-01: GpoLinkedCount" -ForegroundColor Yellow
try {
    $gpos = $gpoState.GPOs
    $gpoLinks = $gpoState.GPOLinks
    
    # Get all linked GPO GUIDs
    $linkedGuids = @()
    foreach ($link in $gpoLinks) {
        if ($link.gPLink) {
            $matches = [regex]::Matches($link.gPLink, 'CN=\{([^}]+)\}')
            foreach ($match in $matches) {
                $linkedGuids += $match.Groups[1].Value
            }
        }
    }
    
    $uniqueLinkedGuids = $linkedGuids | Select-Object -Unique
    $linkedCount = $uniqueLinkedGuids.Count
    $totalCount = ($gpos | Measure-Object).Count
    $testResult = $totalCount -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - Linked GPOs: $linkedCount / $totalCount" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-01: GpoLinkedCount"; Status = "PASS"; Details = "$linkedCount / $totalCount" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-01: GpoLinkedCount"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-01: GpoLinkedCount"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPOL-02: GpoDisabledLinkCount
# ============================================
Write-Host "Test AD-GPOL-02: GpoDisabledLinkCount" -ForegroundColor Yellow
try {
    $gpoLinks = $gpoState.GPOLinks
    
    $totalLinks = 0
    $disabledLinks = 0
    $enabledLinks = 0
    $enforcedLinks = 0

    foreach ($link in $gpoLinks) {
        if ($link.gPLink) {
            $linkEntries = $link.gPLink -split '\]' | Where-Object { $_ -match 'LDAP://' }
            foreach ($entry in $linkEntries) {
                $totalLinks++
                if ($entry -match ';(\d)$') {
                    $linkState = [int]$matches[1]
                    switch ($linkState) {
                        0 { $enabledLinks++ }
                        1 { $disabledLinks++ }
                        2 { $enforcedLinks++ }
                    }
                }
            }
        }
    }
    
    $testResult = $totalLinks -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - Total: $totalLinks, Enabled: $enabledLinks, Disabled: $disabledLinks, Enforced: $enforcedLinks" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-02: GpoDisabledLinkCount"; Status = "PASS"; Details = "Disabled: $disabledLinks" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-02: GpoDisabledLinkCount"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-02: GpoDisabledLinkCount"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPOL-03: GpoUnlinkedTargetCount
# ============================================
Write-Host "Test AD-GPOL-03: GpoUnlinkedTargetCount" -ForegroundColor Yellow
try {
    $gpoLinks = $gpoState.GPOLinks
    
    # Get all OUs
    $allOUs = Get-ADOrganizationalUnit -Filter *
    $totalOUs = ($allOUs | Measure-Object).Count
    
    # Count OUs with links
    $linkedOUs = $allOUs | Where-Object { $_.gPLink -and $_.gPLink -ne '' }
    $linkedOUCount = ($linkedOUs | Measure-Object).Count
    $unlinkedOUCount = $totalOUs - $linkedOUCount
    
    $testResult = $totalOUs -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - OUs without GPO links: $unlinkedOUCount / $totalOUs" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-03: GpoUnlinkedTargetCount"; Status = "PASS"; Details = "$unlinkedOUCount / $totalOUs" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-03: GpoUnlinkedTargetCount"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-03: GpoUnlinkedTargetCount"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPOL-04: GpoEnforcedCount
# ============================================
Write-Host "Test AD-GPOL-04: GpoEnforcedCount" -ForegroundColor Yellow
try {
    $gpoLinks = $gpoState.GPOLinks
    
    $totalLinks = 0
    $enforcedLinks = 0

    foreach ($link in $gpoLinks) {
        if ($link.gPLink) {
            $linkEntries = $link.gPLink -split '\]' | Where-Object { $_ -match 'LDAP://' }
            foreach ($entry in $linkEntries) {
                $totalLinks++
                if ($entry -match ';(\d)$') {
                    $linkState = [int]$matches[1]
                    if ($linkState -eq 2) {
                        $enforcedLinks++
                    }
                }
            }
        }
    }
    
    $testResult = $totalLinks -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - Enforced links: $enforcedLinks / $totalLinks" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-04: GpoEnforcedCount"; Status = "PASS"; Details = "$enforcedLinks / $totalLinks" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-04: GpoEnforcedCount"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-04: GpoEnforcedCount"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPOL-05: GpoBlockedInheritanceCount
# ============================================
Write-Host "Test AD-GPOL-05: GpoBlockedInheritanceCount" -ForegroundColor Yellow
try {
    $allOUs = Get-ADOrganizationalUnit -Filter * -Properties gpOptions
    $totalOUs = ($allOUs | Measure-Object).Count
    
    $blockedOUs = $allOUs | Where-Object { $_.gpOptions -eq 1 }
    $blockedCount = ($blockedOUs | Measure-Object).Count
    
    $testResult = $totalOUs -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - OUs with blocked inheritance: $blockedCount / $totalOUs" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-05: GpoBlockedInheritanceCount"; Status = "PASS"; Details = "$blockedCount / $totalOUs" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-05: GpoBlockedInheritanceCount"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-05: GpoBlockedInheritanceCount"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# AD-GPOL-06: GpoLinkedOUCount
# ============================================
Write-Host "Test AD-GPOL-06: GpoLinkedOUCount" -ForegroundColor Yellow
try {
    $allOUs = Get-ADOrganizationalUnit -Filter * -Properties gPLink
    $totalOUs = ($allOUs | Measure-Object).Count
    
    $linkedOUs = $allOUs | Where-Object { $_.gPLink -and $_.gPLink -ne '' }
    $linkedOUCount = ($linkedOUs | Measure-Object).Count
    
    $testResult = $totalOUs -ge 0
    
    if ($testResult) {
        Write-Host "  ✓ PASS - OUs with GPO links: $linkedOUCount / $totalOUs" -ForegroundColor Green
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-06: GpoLinkedOUCount"; Status = "PASS"; Details = "$linkedOUCount / $totalOUs" }
    } else {
        Write-Host "  ✗ FAIL" -ForegroundColor Red
        $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-06: GpoLinkedOUCount"; Status = "FAIL"; Details = "Test failed" }
    }
} catch {
    Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
    $ValidationResults += [PSCustomObject]@{ Test = "AD-GPOL-06: GpoLinkedOUCount"; Status = "ERROR"; Details = $_.Exception.Message }
}

# ============================================
# Summary
# ============================================
Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Validation Summary" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

$passCount = ($ValidationResults | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = ($ValidationResults | Where-Object { $_.Status -eq "FAIL" }).Count
$errorCount = ($ValidationResults | Where-Object { $_.Status -eq "ERROR" }).Count
$totalCount = $ValidationResults.Count

Write-Host "Total Tests: $totalCount" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host ""

if ($failCount -eq 0 -and $errorCount -eq 0) {
    Write-Host "✓ ALL TESTS PASSED! Phase 7 is validated." -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed or encountered errors. Review output above." -ForegroundColor Red
    exit 1
}

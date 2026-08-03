# Phase 19 GPO State Validation

## Quick Validation (Recommended)

### Option 1: On Domain Controller (Simplest)

1. Copy the Maester module to the DC:
```powershell
# From management machine
Copy-Item -Path ".\powershell" -Destination "\\DC01\C$\temp\maester" -Recurse -Force
```

2. On the DC, run:
```powershell
# Import the module
Import-Module C:\temp\maester\Maester.psd1 -Force

# Quick validation (tests Get-MtADGpoState only)
.\build\activeDirectory\Simple-Validate-Phase19.ps1 -Quick

# Full validation (tests 11 key functions)
.\build\activeDirectory\Simple-Validate-Phase19.ps1

# Detailed validation with output table
.\build\activeDirectory\Simple-Validate-Phase19.ps1 -Detailed
```

### Option 2: Manual PowerShell Verification

```powershell
# 1. Import module
Import-Module .\powershell\Maester.psd1 -Force

# 2. Test the core function
$gpoState = Get-MtADGpoState
$gpoState.GPOs.Count          # Should return number of GPOs
$gpoState.GPOReports.Count    # Should return number of reports

# 3. Test individual functions
Test-MtAdGpoStateTotalCount           # Should return $true
Test-MtAdGpoWmiFilterCount            # Should return $true
Test-MtAdGpoNoPermissionsCount        # Should return $true
Test-MtAdGpoNoAuthenticatedUsersCount # Should return $true
Test-MtAdGpoCpasswordFoundCount       # Should return $true
```

### Option 3: Pester Tests

```powershell
# Run specific Pester tests
Invoke-Pester -Path "tests\Maester\ad\gpostate" -Tag "AD-GPOS-01"

# Run all Phase 19 tests
Invoke-Pester -Path "tests\Maester\ad\gpostate"
```

## Expected Results

### Success Criteria
- ✓ Get-MtADGpoState returns GPO data
- ✓ All Count functions return $true
- ✓ All Details functions return $true
- ✓ No errors in PowerShell console

### Sample Output
```
=== Phase 19 GPO State Simple Validation ===

Running full validation...
Testing Get-MtADGpoState [SETUP]... PASS
Testing Test-MtAdGpoStateTotalCount [AD-GPOS-01]... PASS
Testing Test-MtAdGpoWmiFilterCount [AD-GPOS-02]... PASS
Testing Test-MtAdGpoSettingsDisabledCount [AD-GPOS-04]... PASS
Testing Test-MtAdGpoOwnerDistinctCount [AD-GPOS-08]... PASS
Testing Test-MtAdGpoNoPermissionsCount [AD-GPOREP-01]... PASS
Testing Test-MtAdGpoNoAuthenticatedUsersCount [AD-GPOREP-03]... PASS
Testing Test-MtAdGpoDenyAceCount [AD-GPOREP-07]... PASS
Testing Test-MtAdGpoDisabledLinkCount [AD-GPOREP-12]... PASS
Testing Test-MtAdGpoVersionMismatchCount [AD-GPOREP-15]... PASS
Testing Test-MtAdGpoCpasswordFoundCount [AD-GPOREP-17]... PASS

=== Validation Summary ===
Passed: 11
Failed: 0
Total:  11

✓ All tests passed!
```

## Troubleshooting

### "Get-MtADGpoState returns null"
- Ensure you're running on a domain-joined machine or DC
- Check that ActiveDirectory and GroupPolicy modules are available
- Verify you have permissions to read GPOs

### "Command not found"
- Ensure Maester module is imported: `Import-Module .\powershell\Maester.psd1 -Force`
- Check that functions are exported: `Get-Command Test-MtAdGpo*`

### "Access denied"
- Run PowerShell as Administrator
- Verify you have Domain Admin or equivalent permissions

## Files Created in Phase 19

### PowerShell Functions (27 files)
Location: `powershell/public/ad/gpostate/`

**GPO State Tests (AD-GPOS-01 to AD-GPOS-09):**
- Test-MtAdGpoStateTotalCount.ps1
- Test-MtAdGpoWmiFilterCount.ps1
- Test-MtAdGpoWmiFilterDetails.ps1
- Test-MtAdGpoSettingsDisabledCount.ps1
- Test-MtAdGpoComputerSettingsDisabledDetails.ps1
- Test-MtAdGpoUserSettingsDisabledDetails.ps1
- Test-MtAdGpoAllSettingsDisabledDetails.ps1
- Test-MtAdGpoOwnerDistinctCount.ps1
- Test-MtAdGpoOwnerDetails.ps1

**GPO Report Tests (AD-GPOREP-01 to AD-GPOREP-20):**
- Test-MtAdGpoNoPermissionsCount.ps1
- Test-MtAdGpoNoPermissionsDetails.ps1
- Test-MtAdGpoNoAuthenticatedUsersCount.ps1
- Test-MtAdGpoNoAuthenticatedUsersDetails.ps1
- Test-MtAdGpoNoEnterpriseDcCount.ps1
- Test-MtAdGpoNoDomainComputersCount.ps1
- Test-MtAdGpoDenyAceCount.ps1
- Test-MtAdGpoDenyAceDetails.ps1
- Test-MtAdGpoInheritedPermissionsCount.ps1
- Test-MtAdGpoNoApplyGroupPolicyAceCount.ps1
- Test-MtAdGpoNoApplyGroupPolicyAceDetails.ps1
- Test-MtAdGpoDisabledLinkCount.ps1
- Test-MtAdGpoDisabledLinkDetails.ps1
- Test-MtAdGpoEnforcementCount.ps1
- Test-MtAdGpoVersionMismatchCount.ps1
- Test-MtAdGpoVersionMismatchDetails.ps1
- Test-MtAdGpoCpasswordFoundCount.ps1
- Test-MtAdGpoCpasswordFoundDetails.ps1
- Test-MtAdGpoDefaultPasswordFoundCount.ps1
- Test-MtAdGpoDefaultPasswordFoundDetails.ps1

### Pester Tests (29 files)
Location: `tests/Maester/ad/gpostate/`

### Enhanced Function
- Get-MtADGpoState.ps1 - Extended to collect GPO reports and permissions

### Module Updates
- Maester.psd1 - Added 27 new function exports
- ADTestBacklog.md - Marked Phase 19 complete

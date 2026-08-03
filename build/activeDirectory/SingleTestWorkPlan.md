# Single Test Implementation Work Plan

## Overview

This document provides a step-by-step work plan for implementing a single Active Directory test. Use this template for each test you implement from the backlog.

## Test Information Template

Before starting, fill out this information:

```markdown
**Test ID**: [From backlog, e.g., AD-COMP-01]
**Test Name**: [e.g., ComputerDisabledCount]
**Phase**: [e.g., Phase 1 - Computer Objects]
**Data Source**: [e.g., AdRecon - Computers.csv]
**Assigned To**: [Your name]
**Start Date**: [YYYY-MM-DD]
**Estimated Effort**: [e.g., 30 minutes]
```

---

## Implementation Steps

### Step 1: Understand the Test Requirements

**Action**: Review the test definition in Get-Analysis.ps1

**Questions to Answer**:
- What data source does this test use? (e.g., Computers.csv, get-AdConfiguration.json)
- What specific field(s) are being analyzed?
- What is the expected output format? (count, list, boolean)
- What would be a reasonable pass/fail criteria?

**Example Analysis**:
```powershell
# From Get-Analysis.ps1 - Computers.csv.01
"$file.01"="$(($computers|?{$_.Enabled -eq "False"}|measure).Count)/$(($computers|measure).Count) Computer Objects are Disabled"
```
- **Data Source**: Computers.csv
- **Field**: Enabled
- **Logic**: Count where Enabled = "False", divide by total count
- **Output**: "X/Y Computer Objects are Disabled"
- **Pass Criteria**: Having the data available to calculate the ratio

---

### Step 2: Create the Test Function

**File Location**: `powershell/public/ad/<category>/Test-MtAd<TestName>.ps1`

**Directory Structure**:
```
powershell/public/ad/
├── computer/       # For computer-related tests
├── user/           # For user-related tests
├── group/          # For group-related tests
├── gpo/            # For GPO-related tests
├── dns/            # For DNS-related tests
├── trust/          # For trust-related tests
├── site/           # For site/subnet tests
├── dacl/           # For DACL tests
├── config/         # For configuration tests
└── schema/         # For schema tests
```

**Function Template**:

```powershell
function Test-MtAd<TestName> {
    <#
    .SYNOPSIS
    [Brief description of what the test checks]

    .DESCRIPTION
    [Detailed description of the security control being tested]

    .EXAMPLE
    Test-MtAd<TestName>

    Returns [description of what is returned]

    .LINK
    https://maester.dev/docs/commands/Test-MtAd<TestName>
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Step 2a: Get cached AD data (handles connection check internally)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    # Step 2b: Access the appropriate data from the cache
    $computers = $adState.Computers
    # For user tests: $users = $adState.Users
    # For group tests: $groups = $adState.Groups
    # For DC tests: $dcs = $adState.DomainControllers

    # Step 2c: Perform the test logic
    $disabledComputers = $computers | Where-Object { $_.Enabled -eq "False" }
    $totalComputers = $computers
    
    $disabledCount = ($disabledComputers | Measure-Object).Count
    $totalCount = ($totalComputers | Measure-Object).Count
    
    # Step 2d: Determine test result
    # For informational tests, typically always return $true if data is retrieved
    # For compliance tests, set criteria based on security best practices
    $testResult = $totalCount -gt 0

    # Step 2e: Generate markdown results
    $portalLink = "https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/Overview"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    
    if ($testResult) {
        $testResultMarkdown = "Active Directory computer objects have been analyzed. [View in Azure AD Portal]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions.`n`n%TestResult%"
    }

    # Step 2f: Create detailed results table
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Computers | $totalCount |`n"
    $result += "| Disabled Computers | $disabledCount |`n"
    $result += "| Enabled Computers | $($totalCount - $disabledCount) |`n"
    
    if ($totalCount -gt 0) {
        $percentage = [Math]::Round(($disabledCount / $totalCount) * 100, 2)
        $result += "| Disabled Percentage | $percentage% |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    # Step 2g: Add test result details
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
```

---

### Step 3: Create the Markdown Documentation

**File Location**: `powershell/public/ad/<category>/Test-MtAd<TestName>.md`

**IMPORTANT**: Documentation must be placed in the **same directory** as the PowerShell function, NOT in `website/docs/commands/`.

**Content Focus**: The documentation should explain **WHY the test matters** from a security perspective, not just how to use the function.

**Template**:

```markdown
# Test-MtAd<TestName>

## Why This Test Matters

[Explain the security value:
- What risks does this test identify?
- Why is this configuration important?
- What attacks or compliance issues could arise?
- Real-world scenarios where this matters]

## Security Recommendation

[Actionable guidance:
- What should administrators do based on results?
- Best practices for configuration
- How to remediate issues found
- Industry standards or frameworks that require this]

## How the Test Works

[Brief technical overview:
- What data is analyzed?
- What criteria are used?
- What thresholds or flags are checked?]

## Related Tests

- `Test-MtAd<RelatedTest1>` - [Brief description of relationship]
- `Test-MtAd<RelatedTest2>` - [Brief description of relationship]
```

**Example from Phase 1 (ComputerDisabledCount)**:

```markdown
# Test-MtAdComputerDisabledCount

## Why This Test Matters

Disabled computer accounts that remain in Active Directory represent a security hygiene issue. While disabling a computer account is a valid administrative action (typically when decommissioning systems), these accounts should eventually be removed to:

- **Reduce attack surface**: Disabled accounts can be re-enabled by attackers who gain privileged access
- **Prevent confusion**: Distinguish between active and truly decommissioned systems
- **Maintain directory cleanliness**: Simplify auditing and compliance reporting

## Security Recommendation

Regularly review disabled computer accounts and delete those that are permanently decommissioned.

## How the Test Works

This test retrieves all computer objects and counts disabled vs. total computers.

## Related Tests

- `Test-MtAdComputerDormantCount` - Identifies enabled computers that haven't logged on recently
```

---

### Step 4: Create the Pester Test

**File Location**: `tests/ad/[category]/Test-MtAd[TestName].Tests.ps1`

**Template**:

```powershell
Describe "Active Directory - [Category]" -Tag "AD", "AD.[Category]", "[TestID]" {
    It "[TestID]: [Test description from backlog]" {

        $result = Test-MtAd[TestName]

        if ($null -ne $result) {
            $result | Should -Be $true -Because "[reason for the test]"
        }
    }
}
```

**Example**:

```powershell
Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-01" {
    It "AD-COMP-01: Computer disabled count should be retrievable" {

        $result = Test-MtAdComputerDisabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "computer object data should be accessible"
        }
    }
}
```

---

### Step 5: Update Module Manifest

**File**: `powershell/Maester.psd1`

**Action**: Add the new function to the `FunctionsToExport` array

```powershell
FunctionsToExport = @(
    # ... existing functions ...
    'Test-MtAd[TestName]'
)
```

---

### Step 6: Update Test Index Documentation

**File**: `website/docs/tests/ad/[category].md`

**Action**: Add the new test to the appropriate category documentation

```markdown
| Cmdlet Name | Test ID | Description |
| - | - | - |
| Test-MtAd[TestName] | [TestID] | [Brief description] |
```

---

### Step 7: Test the Implementation

**Actions**:

1. **Import the module**:
   ```powershell
   Import-Module ./powershell/Maester.psd1 -Force
   ```

2. **Test the function directly**:
   ```powershell
   Test-MtAd[TestName] -Verbose
   ```

3. **Run the Pester test**:
   ```powershell
   Invoke-Pester -Path "tests/ad/[category]/Test-MtAd[TestName].Tests.ps1" -Verbose
   ```

4. **Check for errors**:
   - Verify no syntax errors
   - Verify connections are checked properly
   - Verify markdown output is formatted correctly
   - Verify return value is correct type

---

### Step 8: Update the Backlog

**File**: `build/activeDirectory/ADTestBacklog.md`

**Action**: Update the test status

```markdown
| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| [TestID] | [TestName] | [Description] | [Criteria] | 🟢 | [Your name] |
```

---

## Pass/Fail Criteria Guidelines

When determining pass/fail criteria for tests, consider these guidelines:

### Informational Tests (Return $true if data retrieved)

These tests provide visibility into the environment without enforcing specific values:

- Count tests (e.g., "How many disabled computers?")
- Configuration enumeration (e.g., "What OS versions are in use?")
- Status reporting (e.g., "What is the functional level?")

**Pass Criteria**: Data was successfully retrieved and analyzed

### Compliance Tests (Return based on security criteria)

These tests check for specific security configurations:

- SMBv1 enabled (should be $false)
- Reversible encryption (should be $false)
- Password policies (should meet minimum standards)

**Pass Criteria**: Configuration meets security best practices

### Recommended Baselines

| Control | Recommended Pass State | Notes |
|---------|----------------------|-------|
| SMBv1 Enabled | $false | Should be disabled on all DCs |
| Reversible Encryption | $false | Should never be used |
| Password History | >= 24 passwords | Remember sufficient history |
| Max Password Age | <= 90 days | Enforce regular changes |
| Min Password Length | >= 14 characters | NIST recommendation |
| Account Lockout Threshold | <= 5 attempts | Prevent brute force |
| KRBTGT Password Age | < 180 days | Rotate regularly |
| Tombstone Lifetime | >= 180 days | Allow sufficient recovery time |

---

## Common Patterns

### Pattern 1: Simple Count Test

```powershell
$items = Get-Data
$count = ($items | Measure-Object).Count
$testResult = $count -ge 0  # Always true if we got data
```

### Pattern 2: Ratio/Percentage Test

```powershell
$total = Get-TotalCount
$matching = Get-MatchingCount
$percentage = if ($total -gt 0) { ($matching / $total) * 100 } else { 0 }
$testResult = $total -gt 0
```

### Pattern 3: Compliance Check

```powershell
$nonCompliant = Get-Data | Where-Object { $_.Setting -eq "BadValue" }
$testResult = ($nonCompliant | Measure-Object).Count -eq 0
```

### Pattern 4: Existence Check

```powershell
$exists = Test-Path "SomeCriteria"
$testResult = $exists  # Pass if exists, fail if not
```

---

## Checklist

Before marking a test complete, verify:

- [ ] Function file created in correct location
- [ ] Function has proper comment-based help
- [ ] Function checks required connections
- [ ] Function returns [bool] type
- [ ] Function generates markdown output
- [ ] Markdown documentation created
- [ ] Pester test file created with proper tags
- [ ] Module manifest updated
- [ ] Test index documentation updated
- [ ] Function tested locally
- [ ] Pester tests pass
- [ ] Backlog updated with completion status

---

## Phase Completion Requirements

**⚠️ CRITICAL: After completing ALL tests in a phase, you MUST commit and push your changes ⚠️**

### Final Commit Checklist

- [ ] All test functions implemented (19 for Phase 4)
- [ ] All Pester test files created
- [ ] All markdown documentation written
- [ ] Module manifest updated with new function exports
- [ ] Backlog updated with all tests marked 🟢
- [ ] **Changes staged** (`git add powershell/public/ad/[category]/ tests/ad/[category]/ powershell/Maester.psd1 build/activeDirectory/ADTestBacklog.md`)
- [ ] **Changes committed** (`git commit -m "Complete Phase X: [Phase Name] - Y tests implemented"`)
- [ ] **Changes pushed** (`git push origin [branch-name]`)
- [ ] **Push verified** (`git log --oneline -3` shows your commit)

### Commit Commands Template

```bash
# Stage all changes
git add powershell/public/ad/[category]/
git add tests/ad/[category]/
git add powershell/Maester.psd1
git add build/activeDirectory/ADTestBacklog.md

# Commit with descriptive message
git commit -m "Complete Phase X: [Phase Name] - Y tests implemented

- Added Y test functions in powershell/public/ad/[category]/
- Added Y Pester test files in tests/ad/[category]/
- Added Y markdown documentation files
- Updated Maester.psd1 module manifest with new function exports
- Updated ADTestBacklog.md to mark Phase X complete"

# Push to remote
git push origin [branch-name]

# Verify
git log --oneline -3
git status
```

**DO NOT CONSIDER A PHASE COMPLETE UNTIL CHANGES ARE COMMITTED AND PUSHED!**

---

## Troubleshooting

### Issue: Function not found

**Solution**: Ensure the function is exported in Maester.psd1

### Issue: Test returns null

**Solution**: Check that connection validation is working and returning $null when not connected

### Issue: Markdown not displaying correctly

**Solution**: Verify markdown syntax, especially table formatting with proper `| --- |` separators

### Issue: Pester test fails

**Solution**: Check the Should assertion and ensure the function returns the expected boolean value

---

## Example: Complete Implementation

See the existing implementations for reference:

- **CISA Example**: `powershell/public/cisa/exchange/Test-MtCisaAttachmentFileType.ps1`
- **CIS Example**: `powershell/public/cis/Test-MtCisCloudAdmin.ps1`

---

## Next Steps

After completing this test:

1. Select the next test from the same phase
2. Repeat this work plan
3. When phase is complete, move to next phase
4. Update the backlog summary statistics

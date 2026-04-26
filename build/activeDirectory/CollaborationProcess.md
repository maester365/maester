# Multi-Session Collaboration Process

## Overview

This document defines the process for multiple sessions to collaborate on implementing the Active Directory test backlog. The goal is to enable parallel work while maintaining consistency and avoiding conflicts.

## Principles

1. **Phase-Based Assignment**: Each session works on a complete phase
2. **Test-Level Tracking**: Individual tests are tracked in the backlog
3. **Documentation First**: Update backlog before starting work
4. **Complete Before Moving**: Finish all tests in a phase before taking another
5. **Communication Through Backlog**: Use backlog updates to communicate status

---

## Session Workflow

### Step 1: Pre-Work Checklist

Before starting work, complete these steps:

1. **Pull latest changes**:
   ```bash
   git pull origin main
   ```

2. **Review current backlog status**:
   - Open `build/activeDirectory/ADTestBacklog.md`
   - Identify which phases are:
     - 🔴 Not Started (available to claim)
     - 🟡 In Progress (claimed by another session)
     - 🟢 Complete (finished)

3. **Claim a phase**:
   - Select a 🔴 phase
   - Update the backlog to mark it 🟡
   - Add your session identifier to "Assigned To"

### Step 2: Phase Claim Template

Update the backlog with this information at the start of your session:

```markdown
## Phase X: [Phase Name]

**Status**: 🟡 In Progress
**Claimed By**: [Session ID/Name]
**Claimed Date**: [YYYY-MM-DD]
**Estimated Completion**: [YYYY-MM-DD]
**Tests Completed**: 0/[Total]
```

### Step 3: Work Through Tests

For each test in your claimed phase:

1. **Select next unimplemented test** in your phase
2. **Follow the Single Test Work Plan** (`SingleTestWorkPlan.md`)
3. **Update test status** in backlog after each test:
   ```markdown
   | AD-COMP-01 | ComputerDisabledCount | ... | ... | 🟡 | [Your name] |
   ```
4. **Commit after each test**:
   ```bash
   git add .
   git commit -m "Implement AD-COMP-01: ComputerDisabledCount test"
   ```

### Step 4: Phase Validation (REQUIRED)

Before marking a phase complete, you MUST validate all tests against the live domain controller:

1. **Copy module to DC**:
   ```bash
   scp -i ~/.ssh/test_key -r ./powershell/* azureuser@20.125.96.137:/tmp/
   ```

2. **Connect to DC and run validation**:
   ```bash
   ssh -i ~/.ssh/test_key azureuser@20.125.96.137
   ```

3. **Execute validation script**:
   ```powershell
   Import-Module ActiveDirectory
   # Run each test function and verify results
   Test-MtAd[TestName]
   ```

4. **Document results** in `AD-TEST-RESULTS.md`

5. **Validation Checklist**:
   - [ ] All functions execute without errors
   - [ ] Functions return expected data types
   - [ ] Markdown output is generated correctly
   - [ ] Results documented in AD-TEST-RESULTS.md

### Step 5: Phase Completion (REQUIRED)

**⚠️ CRITICAL: DO NOT SKIP THIS STEP ⚠️**

After validation is complete, you **MUST** commit and push your changes:

1. **Stage all changes**:
   ```bash
   git add powershell/public/ad/[category]/
   git add tests/ad/[category]/
   git add powershell/Maester.psd1
   git add powershell/public/Get-MtADDomainState.ps1
   git add build/activeDirectory/ADTestBacklog.md
   ```

2. **Commit with descriptive message**:
   ```bash
   git commit -m "Complete Phase X: [Phase Name] - Y tests implemented and validated"
   ```

3. **Push to remote repository**:
   ```bash
   git push origin [branch-name]
   ```

4. **Verify push succeeded**:
   ```bash
   git log --oneline -3
   git status
   ```

5. **Update phase status in backlog**:
   ```markdown
   ## Phase X: [Phase Name]
   
   **Status**: 🟢 Complete
   **Completed By**: [Session ID/Name]
   **Completed Date**: [YYYY-MM-DD]
   **Tests Completed**: [Total]/[Total]
   **Validated**: Yes - All tests executed successfully against live DC
   **Committed**: Yes - Changes pushed to remote
   ```

6. **Update summary statistics** at bottom of backlog

---

## Pre-Completion Checklist

Before considering a phase complete, verify ALL of the following:

### Code Changes
- [ ] All test functions implemented and working
- [ ] All Pester tests created with proper tags
- [ ] All markdown documentation written
- [ ] Module manifest updated with new functions
- [ ] Get-MtADDomainState extended if needed (for new data sources)

### Validation (REQUIRED)
- [ ] All tests validated against live domain controller
- [ ] Test results documented in AD-TEST-RESULTS.md
- [ ] No errors during test execution

### Git Commit (REQUIRED - DO NOT SKIP)
- [ ] Changes staged (git add)
- [ ] Changes committed with descriptive message (git commit)
- [ ] Changes pushed to remote (git push)
- [ ] Push verified successful

### Backlog Update
- [ ] Phase status updated to 🟢 Complete
- [ ] All individual tests marked 🟢
- [ ] Summary statistics updated
- [ ] Completion date recorded

---

## Backlog Update Protocol

### Status Updates

Update the backlog **immediately** when:

- Claiming a phase (🔴 → 🟡)
- Starting a test (update "Assigned To")
- Completing a test (🟡 → 🟢)
- Encountering a blocker (🟡 → ⚫)

### Update Format

Use this format for test-level updates:

```markdown
| Test ID | Test Name | Description | Pass Criteria | Status | Assigned To |
|---------|-----------|-------------|---------------|--------|-------------|
| AD-COMP-01 | ComputerDisabledCount | Count of disabled computer objects | Returns count of disabled/total computers | 🟢 | Session-A |
| AD-COMP-02 | ComputerDormantCount | Count of dormant computers | Returns count of dormant/total computers | 🟡 | Session-A |
| AD-COMP-03 | ComputerCreatorSidCount | Computers with CreatorSid | Returns count of computers with CreatorSid | 🔴 | Unassigned |
```

---

## Conflict Resolution

### Scenario 1: Two Sessions Want Same Phase

**Resolution**: First session to update backlog claims the phase

**Prevention**: 
- Always pull latest before claiming
- Update backlog immediately when claiming
- Use unique session identifiers

### Scenario 2: Overlapping File Changes

**Resolution**:
1. Both sessions pull latest
2. Identify overlapping files
3. Coordinate to avoid conflicts:
   - Each session works on different tests
   - Use different function names
   - Commit frequently

**Prevention**:
- Each test has unique function name
- Tests are independent
- Backlog tracks who is working on what

### Scenario 3: Unclear Pass/Fail Criteria

**Resolution**:
1. Check existing similar tests for patterns
2. Make reasonable assumption based on security best practices
3. Document assumption in test comments
4. Mark test with note in backlog

**Documentation Format**:
```markdown
| AD-COMP-05 | ComputerSidHistoryCount | ... | ... | 🟢 | Session-A |
| *Note*: Assumed any SID History is informational; no specific threshold set |
```

---

## Session Identification

Use consistent session identifiers:

| Format | Example | Use Case |
|--------|---------|----------|
| Git username | `jdoe` | Individual contributors |
| Team name | `team-security` | Team-based work |
| Date-based | `2024-01-15-session` | Time-boxed sprints |
| Feature branch | `feature/ad-tests-phase-1` | Branch-based work |

---

## Communication Templates

### Claiming a Phase

```markdown
**Session**: [Session ID]
**Action**: Claiming Phase [X] - [Phase Name]
**Date**: [YYYY-MM-DD]
**Tests to Implement**: [Count]
**Estimated Completion**: [YYYY-MM-DD]
```

### Completing a Test

```markdown
**Session**: [Session ID]
**Action**: Completed [Test ID] - [Test Name]
**Date**: [YYYY-MM-DD]
**Notes**: [Any special considerations]
```

### Encountering a Blocker

```markdown
**Session**: [Session ID]
**Action**: Blocked on [Test ID] - [Test Name]
**Date**: [YYYY-MM-DD]
**Issue**: [Description of blocker]
**Tried**: [What you've attempted]
**Need**: [What help is needed]
```

### Completing a Phase

```markdown
**Session**: [Session ID]
**Action**: Completed Phase [X] - [Phase Name]
**Date**: [YYYY-MM-DD]
**Tests Implemented**: [Count]
**Tests Skipped**: [Count and reasons]
**Notes**: [Any patterns discovered, reusable code, etc.]
```

---

## Recommended Phase Order

While phases can be worked in parallel, this order minimizes dependencies:

1. **Phase 1: Computer Objects** - Good starting point, straightforward
2. **Phase 3: Password Policies** - Independent, clear criteria
3. **Phase 5: Domain & Forest** - Core AD info, well-defined
4. **Phase 9: Users** - Large but straightforward
5. **Phase 8: Groups** - Builds on user concepts
6. **Phase 10: OUs** - Simple structure tests
7. **Phase 11: Sites and Subnets** - Network topology
8. **Phase 12: Trusts** - Security-focused
9. **Phase 6: Domain Controllers** - Infrastructure
10. **Phase 4: DNS** - Can be complex
11. **Phase 2: SPNs** - Requires understanding of services
12. **Phase 7: GPO** - Policy analysis
13. **Phase 13: Schema** - Advanced topic
14. **Phases 14-20**: Domain State and DACL - Complex analysis

---

## Parallel Work Strategy

### Maximum Parallel Sessions

| Resource | Max Parallel |
|----------|-------------|
| Phases | 5-6 (one per category) |
| Tests per phase | 1 (sequential within phase) |
| Same directory | 1 (to avoid file conflicts) |

### Recommended Parallel Assignments

**Option 1: By Category**
- Session A: Computer-related (Phases 1, 6)
- Session B: User/Group (Phases 8, 9)
- Session C: Policy (Phases 3, 7)
- Session D: Infrastructure (Phases 4, 5, 11)
- Session E: Advanced (Phases 12, 13, 14-20)

**Option 2: By Complexity**
- Session A: Simple (Phases 1, 3, 5, 10)
- Session B: Medium (Phases 6, 8, 9, 11)
- Session C: Complex (Phases 2, 4, 7, 12)
- Session D: Advanced (Phases 13-20)

---

## Quality Gates

Before marking a phase complete, verify:

### Live Validation (REQUIRED)
- [ ] All tests executed against live domain controller (20.125.96.137)
- [ ] Test results documented in AD-TEST-RESULTS.md
- [ ] No errors during test execution
- [ ] Functions return expected data types
- [ ] Markdown output renders correctly

### Code Quality
- [ ] All functions follow naming convention
- [ ] All functions have comment-based help
- [ ] All functions check connections
- [ ] All functions return [bool]
- [ ] No hardcoded values (use parameters)

### Test Quality
- [ ] All Pester tests have proper tags
- [ ] All Pester tests have meaningful descriptions
- [ ] Tests can be run independently
- [ ] Tests handle null results gracefully

### Documentation Quality
- [ ] All markdown docs follow template (security-focused content)
- [ ] Documentation placed in same directory as function (NOT in website/docs/)
- [ ] Documentation explains WHY the test matters, not just HOW to use it
- [ ] Module manifest is updated

### Backlog Quality
- [ ] All tests marked complete
- [ ] Summary statistics updated
- [ ] Any notes or assumptions documented

---

## Quick Reference

### File Locations

| Component | Location | Notes |
|-----------|----------|-------|
| Test Functions | `powershell/public/ad/[category]/` | Create category subdirectory if needed |
| Pester Tests | `tests/Maester/ad/[category]/` | Mirror the function directory structure |
| Markdown Docs | `powershell/public/ad/[category]/` | **SAME as function location** |
| Module Manifest | `powershell/Maester.psd1` | Add function to `FunctionsToExport` |
| Test Index | `website/docs/tests/ad/[category].md` | Optional - for test catalog |
| Backlog | `build/activeDirectory/ADTestBacklog.md` | Update status as you work |
| Work Plan | `build/activeDirectory/SingleTestWorkPlan.md` | Reference for implementation |
| This Process | `build/activeDirectory/CollaborationProcess.md` | This file |

### Common Commands

```bash
# Pull latest changes
git pull origin main

# Check status
git status

# Add changes
git add .

# Commit with message
git commit -m "Implement AD-XXX-XX: TestName"

# Push changes
git push origin main

# View backlog
cat build/activeDirectory/ADTestBacklog.md

# Count remaining tests
grep -c "🔴" build/activeDirectory/ADTestBacklog.md
```

---

## Questions?

If you have questions about:

- **Test implementation**: See `SingleTestWorkPlan.md`
- **Test requirements**: See `Get-Analysis.ps1` comments
- **Existing patterns**: See `powershell/public/cisa/` or `powershell/public/cis/`
- **Process issues**: Update this document with findings

---

## Lessons Learned from Phase 1 Implementation

### What Worked Well

1. **Parallel exploration agents**: Using multiple background agents to explore patterns simultaneously saved time and provided comprehensive context
2. **Caching via Get-MtADDomainState**: The existing cache mechanism works well for AD tests - no need to implement custom caching
3. **Consistent function structure**: Following the established pattern (connection check → data retrieval → analysis → markdown output) produces clean, maintainable code

### What Needed Correction

1. **Documentation location**: Initially placed docs in `website/docs/commands/` but they should be **co-located with functions** in `powershell/public/ad/[category]/`
2. **Documentation content**: Initial docs focused too much on function usage (tactical). Should focus on **security value** (strategic):
   - Why does this test matter?
   - What risks does it identify?
   - What should administrators do?
3. **Connection checking**: Use `Get-MtADDomainState` and check for `$null` result rather than `Test-MtConnection ActiveDirectory` (which doesn't exist)

### Patterns to Follow

**Data Access Pattern**:
```powershell
$adState = Get-MtADDomainState
if ($null -eq $adState) {
    Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
    return $null
}
$computers = $adState.Computers
```

**Return Value Convention**:
- Informational tests: Return `$true` if data retrieved successfully
- Compliance tests: Return `$true`/`$false` based on security criteria
- Always return `$null` when AD is not available

**Documentation Template**:
```markdown
# FunctionName

## Why This Test Matters
[Security value proposition]

## Security Recommendation
[Actionable guidance]

## How the Test Works
[Technical overview]

## Related Tests
[Links to complementary tests]
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-25 | Initial collaboration process + Phase 1 learnings |

---

**Remember**: When in doubt, document your assumption and proceed. It's easier to refine than to wait for perfect clarity.

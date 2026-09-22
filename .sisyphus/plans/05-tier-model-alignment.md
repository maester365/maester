# Plan 5: Active Directory Tier Model Alignment

## TL;DR
> **Scope**: Align Maester's Active Directory security checks with Microsoft's Active Directory Tier Model guidance. Map existing checks, identify gaps, and implement new checks for tier separation, privileged access hygiene, and administrative forest controls.
> **Deliverables**: Tier Model coverage matrix, gap analysis, new/modified checks, documentation.
> **Effort**: L–XL
> **Parallel**: YES — 3 waves. **Research waves (Tasks 21–22) can run in parallel with Plans 1–3.** Implementation waves (Tasks 23–25) require Plan 2 query catalog stability.
> **Prerequisite**: Plan 1 (AD Protocol Foundation) for protocol primitives; Plan 2 (LDAP Collectors) for directory-state queries. Can begin research in parallel with protocol work.

## Context
Microsoft's Tier Model (formerly ESAE / Red Forest) defines a privileged access strategy that isolates credentials and systems into three tiers:
- **Tier 0**: Direct control of enterprise identity — domain controllers, AD admins, certificate services, identity federation
- **Tier 1**: Control of server workloads — application servers, database servers, virtualization hosts
- **Tier 2**: Control of user workstations and devices — helpdesk, workstation admins

The model requires:
- No cross-tier credential exposure (clean source principle)
- Privileged Access Workstations (PAW) for Tier 0/1
- Restricted groups and authentication policies per tier
- Separate administrative forests for Tier 0 (optional but recommended)
- Time-bound privileges (Privileged Access Management, JIT/JEA)

This plan adds Tier Model coverage to Maester's AD test suite without modifying the protocol layer.

### Definition of Done
- Tier Model coverage matrix exists in `.sisyphus/evidence/` and maps every Microsoft control to existing or new Maester checks.
- Every new check has a Pester fixture with pass/fail/boundary cases and follows Maester naming conventions.
- All new checks are gated by the AD opt-in guard and use only protocol primitives from Plans 1–3.
- Documentation accurately represents coverage, gaps, and tier-boundary configuration options.
- Existing AD check suite passes without regression.
- All E2E validation of new checks follows the Plan 9 three-track mandatory process: hard preflight gate (`Test-LabPrerequisites.ps1`), protocol probe matrix (`Invoke-ProtocolProbeMatrix.ps1`), and public E2E runner matrix (`Invoke-PublicE2EMatrix.ps1`) against the canonical lab topology (`MiSouleDC02/misoule02.local`, `MiSouleDC03/child.misoule02.local`, `MiSouleDC04/misoule03.local`, `MiSouleRunnerWin`, `MiSouleRunnerLinux`).

### Must NOT Have
- No new module dependencies beyond what Plans 1–3 already require.
- No checks that require local registry, SCCM, Intune, or endpoint agents.
- No hardcoded tier boundaries; tier definitions must be configurable or detectable.
- No false positives for environments not using administrative forests or PAWs.
- No changes to protocol layer, targeting, or credential handling.

## Wave 1: Research & Gap Analysis (Tasks 21–22)

### Task 21 — Map existing Maester AD checks to Tier Model controls
**What to do**:
- Review Microsoft documentation: `https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/tier-model`
- Review Microsoft reference implementation: `https://github.com/microsoft/ActiveDirectoryTierModel`
- Catalog every Tier Model control, recommendation, and detection pattern from both sources.
- Map each control to existing Maester AD checks under `powershell/public/ad/**`.
- Identify: (a) fully covered, (b) partially covered, (c) not covered.
- Document the mapping in a machine-readable matrix (CSV/JSON) stored under `.sisyphus/evidence/`.

**Must NOT do**: Do not modify existing checks during research; do not assume GitHub repo content matches current docs—check both.

**Recommended Agent Profile**:
- Category: `deep` — Reason: requires cross-referencing external documentation, GitHub repo content, and existing codebase
- Skills: [] — research and static analysis only

**Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 22 | Blocked by: none

**References**:
- Pattern: `powershell/public/ad/**` — existing check implementations to map
- External: `https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/tier-model` — Microsoft Tier Model docs
- External: `https://github.com/microsoft/ActiveDirectoryTierModel` — reference implementation
- Test: `powershell/tests/functions/ActiveDirectoryOptIn.Tests.ps1` — existing AD test coverage

**Acceptance Criteria**:
- [ ] Every Tier Model control from both sources has an entry in the coverage matrix.
- [ ] Every existing Maester AD check is mapped to zero or more controls.
- [ ] Gap list identifies specific missing controls with priority (must/should/could).

**QA Scenarios**:
```
Scenario: Coverage matrix is complete and machine-readable
  Tool: Bash
  Steps: Validate JSON/CSV schema; count controls from both sources; verify every Maester AD check appears.
  Expected: Matrix file exists; no missing controls; no orphaned checks.
  Evidence: .sisyphus/evidence/task-21-matrix.json

Scenario: Gap list has priorities
  Tool: Bash
  Steps: Verify every not-covered control has must/should/could priority and rationale.
  Expected: No unclassified gaps; priorities justified by risk/exploitability.
  Evidence: .sisyphus/evidence/task-21-gaps.txt
```

---

### Task 22 — Define Tier Model check contracts and data requirements
**What to do**:
- For each gap identified in Task 21, define the exact LDAP/WMI/SYSVOL data needed to evaluate the control.
- Determine whether each gap requires: (a) new collector state in `Get-MtADDomainState`, (b) new query in the LDAP catalog, (c) new standalone check, or (d) modification to existing check.
- Define pass/fail criteria and severity levels (Critical/High/Medium/Low) for each new check.
- Cross-reference with Plan 1 fixtures to ensure required attributes are already collected or flag new collection needs.

**Must NOT do**: Do not define checks that require protocol changes beyond what Plans 1–3 already provide; do not propose checks that need new transport mechanisms (e.g., local registry, SCCM, Intune).

**Recommended Agent Profile**:
- Category: `deep` — Reason: requires understanding of Plan 1 fixtures, Plan 2 query catalog, and existing check contracts
- Skills: [] — contract design and static analysis

**Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 23–26 | Blocked by: 21

**References**:
- Pattern: Plan 1 fixtures — verify required attributes are collectable
- Pattern: Plan 2 query catalog — determine if new queries are needed
- API/Type: `powershell/public/Get-MtADDomainState.ps1` — collector state contracts
- External: `https://github.com/microsoft/ActiveDirectoryTierModel` — control definitions

**Acceptance Criteria**:
- [ ] Every must-have gap has a defined data contract, collector dependency, and pass/fail logic.
- [ ] No new check requires transport beyond LDAP, SYSVOL, or WinRM/PSRP already planned.
- [ ] Contracts are compatible with Plan 1 fixture schemas.

**QA Scenarios**:
```
Scenario: Every must-have gap has a contract
  Tool: Bash
  Steps: Count must-have gaps from Task 21; verify each has data contract, collector dependency, pass/fail logic, and severity.
  Expected: Zero must-have gaps without contracts; all contracts reference existing or planned collector state.
  Evidence: .sisyphus/evidence/task-22-contracts.txt

Scenario: Fixture compatibility check
  Tool: Bash (pwsh/Pester)
  Steps: For each contract requiring new attributes, verify Plan 1 fixtures can be extended without breaking existing checks.
  Expected: All contracts compatible; no fixture changes break baseline tests.
  Evidence: .sisyphus/evidence/task-22-fixtures.txt
```

## Wave 2: Check Implementation (Tasks 23–25)

### Task 23 — Implement Tier 0 isolation and credential hygiene checks
**What to do**:
- Implement checks for:
  - Domain Admin / Enterprise Admin / Schema Admin membership enumeration and restricted group validation
  - Tier 0 accounts with SPNs (kerberoasting risk)
  - Tier 0 accounts with unconstrained / constrained delegation
  - Tier 0 accounts without smart card / PKI requirements
  - Tier 0 accounts with passwords not meeting hardened policy
  - Presence and enforcement of Authentication Silos / Authentication Policies for Tier 0
  - Protected Users group membership for Tier 0 accounts
  - LAPS deployment and coverage on Tier 0 systems
  - Tier 0 service accounts (gMSA / sMSA usage vs. user accounts)
- Use existing LDAP query catalog and normalizers from Plan 2.
- Add new LDAP queries only if Task 22 flagged them; otherwise query collector state.

**Must NOT do**: Do not hardcode tier boundaries; use configurable parameters or detect from Authentication Silos / OU structure. Do not assume every environment uses the same tier labels.

**Recommended Agent Profile**:
- Category: `deep` — Reason: security-sensitive check logic requiring precise LDAP semantics and group membership handling
- Skills: [] — check implementation and Pester fixture design

**Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 26 | Blocked by: 22 (and Plan 2 Tasks 6–7)

**References**:
- Pattern: `powershell/public/ad/domaincontroller/**` — existing DC/check patterns
- Pattern: `powershell/public/ad/group/**` — existing group check patterns
- External: `https://github.com/microsoft/ActiveDirectoryTierModel` — Tier 0 control definitions
- API/Type: Plan 2 query catalog — `Get-MtLdap*` normalizers and group membership helpers

**Acceptance Criteria**:
- [ ] Each check has a Pester fixture with pass/fail/boundary cases.
- [ ] Checks follow existing Maester naming: `Test-MtAD<TierModelConcept>.ps1`.
- [ ] All checks are gated by the AD opt-in guard.
- [ ] Tier boundaries are configurable or auto-detected; no hardcoded SIDs or group names.

**QA Scenarios**:
```
Scenario: Tier 0 check passes for well-configured environment
  Tool: Bash (pwsh/Pester)
  Steps: Run each new check against fixture with compliant Tier 0 configuration.
  Expected: All checks pass; no false positives.
  Evidence: .sisyphus/evidence/task-23-pass.txt

Scenario: Tier 0 check fails for misconfigured environment
  Tool: Bash (pwsh/Pester)
  Steps: Run each new check against fixture with non-compliant Tier 0 configuration.
  Expected: Correct checks fail with accurate descriptions; severity matches contract.
  Evidence: .sisyphus/evidence/task-23-fail.txt

Scenario: No tier separation is handled gracefully
  Tool: Bash (pwsh/Pester)
  Steps: Run checks against fixture with no Authentication Silos, no PAW OUs, and no tier labels.
  Expected: Checks skip with informational guidance; no crashes or false positives.
  Evidence: .sisyphus/evidence/task-23-no-tier.txt
```

---

### Task 24 — Implement administrative forest and PAW hygiene checks
**What to do**:
- Implement checks for:
  - Administrative forest / bastion forest presence and trust configuration (if detectable via trusts)
  - PAW OU structure and GPO linkage (detectable via LDAP/SYSVOL)
  - Tier 0 admin logon restrictions (workstation restrictions on admin accounts)
  - Deny network logon rights for Tier 0 accounts on Tier 1/2 systems (via GPO / `GptTmpl.inf` parsing)
  - RestrictedAdminMode / RemoteCredentialGuard requirements for Tier 0 remote access
  - Time-based group membership / PAM (Privileged Access Management) configuration where detectable
- GPO-derived checks should reuse Task 8/10 GPO metadata and SYSVOL parsers.

**Must NOT do**: Do not require local group policy or registry access on endpoints; derive everything from directory/LDAP, SYSVOL, or remote WMI.

**Recommended Agent Profile**:
- Category: `deep` — Reason: requires GPO/SYSVOL parsing and trust semantics from Plan 3
- Skills: [] — GPO-derived check implementation

**Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 26 | Blocked by: 22 (and Plan 3 Tasks 8–10)

**References**:
- Pattern: Plan 3 SYSVOL/GPO state — `Get-MtADGpoState.ps1` and `Get-MtSysvolContent.ps1`
- Pattern: `powershell/public/ad/gpo/**` — existing GPO check patterns
- External: `https://github.com/microsoft/ActiveDirectoryTierModel` — PAW and admin forest guidance
- External: MS-GPOL spec — GPO parsing semantics

**Acceptance Criteria**:
- [ ] Each check validates against fixture GPO/link/ACL data.
- [ ] Checks distinguish between "not configured" (skip/info) and "misconfigured" (fail).
- [ ] No false positives for environments not using administrative forests or PAWs.

**QA Scenarios**:
```
Scenario: PAW checks detect missing configuration
  Tool: Bash (pwsh/Pester)
  Steps: Run checks against fixture with no PAW OUs and no admin forest trusts.
  Expected: Checks skip with info; no false positives.
  Evidence: .sisyphus/evidence/task-24-no-paw.txt

Scenario: PAW checks detect misconfiguration
  Tool: Bash (pwsh/Pester)
  Steps: Run checks against fixture with PAW OUs present but missing GPO links or incorrect logon restrictions.
  Expected: Correct checks fail; others pass or skip appropriately.
  Evidence: .sisyphus/evidence/task-24-paw-fail.txt

Scenario: Admin forest trust detection
  Tool: Bash (pwsh/Pester)
  Steps: Run checks against fixture with and without bastion forest trusts.
  Expected: Trust presence correctly detected; missing trust reported as info (not fail).
  Evidence: .sisyphus/evidence/task-24-trusts.txt
```

---

### Task 25 — Implement cross-tier access and delegation hygiene checks
**What to do**:
- Implement checks for:
  - Cross-tier group nesting (e.g., Tier 1 admin in Tier 0 group, Tier 2 admin in Tier 1 group)
  - Cross-tier OU delegation (DACLs on Tier 0 OUs granted to Tier 1/2 principals)
  - Tier 0 credential exposure in Tier 1/2 systems (service accounts, scheduled tasks via GPP XML in SYSVOL)
  - SID history on Tier 0 accounts (migration risk)
  - AdminSDHolder / SDProp propagation issues affecting Tier 0
  - ACL inheritance blocking on Tier 0 objects
- Reuse DACL parsing from Plan 2 and SYSVOL parsing from Plan 3.

**Must NOT do**: Do not flag legitimate break-glass or emergency access accounts if they are documented in a detectable way (e.g., specific OU or group membership); focus on systemic misconfiguration.

**Recommended Agent Profile**:
- Category: `deep` — Reason: requires DACL parsing, group nesting traversal, and SYSVOL GPP XML analysis
- Skills: [] — ACL and delegation check implementation

**Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 26 | Blocked by: 22 (and Plan 2 Tasks 6–7, Plan 3 Tasks 8–10)

**References**:
- Pattern: `Get-MtADDacls.ps1` — DACL parsing contract from Plan 2
- Pattern: `Get-MtADGpoState.ps1` — GPO/SYSVOL state from Plan 3
- Pattern: `powershell/public/ad/group/**` — existing group nesting patterns
- External: `https://github.com/microsoft/ActiveDirectoryTierModel` — delegation guidance

**Acceptance Criteria**:
- [ ] Cross-tier checks use configurable tier-boundary definitions or detect from Authentication Silos.
- [ ] Each check has explicit handling for environments without tier separation (skip with guidance).
- [ ] DACL-based checks reuse `Get-MtADDacls` contract and do not reimplement ACL parsing.

**QA Scenarios**:
```
Scenario: Cross-tier nesting detected
  Tool: Bash (pwsh/Pester)
  Steps: Run checks against fixture with Tier 1 group nested into Tier 0 group.
  Expected: Check fails with specific nesting path and tier labels.
  Evidence: .sisyphus/evidence/task-25-nesting.txt

Scenario: Cross-tier delegation detected
  Tool: Bash (pwsh/Pester)
  Steps: Run checks against fixture with Tier 2 principal having Write permissions on Tier 0 OU.
  Expected: Check fails with principal, OU, and permission details.
  Evidence: .sisyphus/evidence/task-25-delegation.txt

Scenario: Break-glass accounts are excluded
  Tool: Bash (pwsh/Pester)
  Steps: Run checks against fixture with documented emergency access account in Tier 0 group.
  Expected: Account is excluded from findings if documented in detectable OU/group.
  Evidence: .sisyphus/evidence/task-25-breakglass.txt

Scenario: No tier separation environment
  Tool: Bash (pwsh/Pester)
  Steps: Run checks against fixture with no tier boundaries defined.
  Expected: All cross-tier checks skip with guidance; no false positives.
  Evidence: .sisyphus/evidence/task-25-no-tier.txt
```

## Wave 3: Documentation & Validation (Task 26)

### Task 26 — Document Tier Model alignment and validate coverage
**What to do**:
- Update `website/docs/monitoring/active-directory.md` (from Plan 4 Task 16) with a Tier Model section: what Maester checks, what it does not check, and why.
- Document the tier-boundary configuration options (e.g., groups/OU paths that define each tier).
- Produce a coverage report comparing Maester checks to Microsoft Tier Model controls.
- Run all new checks against the Azure E2E lab from Plan 4 under the Plan 9 three-track mandatory validation process (if available) or against fixtures.
- Validate that new checks do not regress existing check performance or results.

**Must NOT do**: Do not claim full Tier Model compliance if gaps remain; document gaps honestly. Do not add checks that require endpoint agents or non-directory data sources.

**Recommended Agent Profile**:
- Category: `writing` — Reason: documentation and coverage reporting
- Skills: [] — docs, report generation, and validation

**Parallelization**: Can Parallel: NO | Wave 3 | Blocks: Final verification | Blocked by: 23–25 (and Plan 4 Task 16 for docs base)

**References**:
- Pattern: Plan 4 Task 16 docs — `website/docs/monitoring/active-directory.md` base document
- Pattern: `website/docs/**` — existing documentation structure and style
- Pattern: `powershell/tests/**` — existing test suites for regression validation
- External: `https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/tier-model` — authoritative source for coverage comparison

**Acceptance Criteria**:
- [ ] Documentation includes a table mapping every implemented check to its Tier Model control source.
- [ ] Coverage report shows percentage of must-have controls covered.
- [ ] All new checks pass Pester fixtures and do not break existing AD check suites.
- [ ] No new module dependencies beyond what Plans 1–3 already require.

**QA Scenarios**:
```
Scenario: Documentation is complete and accurate
  Tool: Bash (docs grep/link validation)
  Steps: Verify every new check appears in docs; verify every Tier Model section has source citations; check for broken links.
  Expected: No orphaned checks; no broken links; gaps honestly documented.
  Evidence: .sisyphus/evidence/task-26-docs.txt

Scenario: Coverage report is reproducible
  Tool: Bash (pwsh)
  Steps: Regenerate coverage report from Task 21 matrix and current check list; compare to manual audit.
  Expected: Report percentages match manual count; must/should/could breakdown accurate.
  Evidence: .sisyphus/evidence/task-26-coverage.txt

Scenario: Existing AD checks do not regress
  Tool: Bash (pwsh/Pester)
  Steps: Run full AD check suite (existing + new) against fixtures and compare to baseline.
  Expected: All existing checks produce identical results; new checks add value without side effects.
  Evidence: .sisyphus/evidence/task-26-regression.txt

Scenario: E2E validation against live lab
  Tool: Bash (pwsh/Pester)
  Steps: If Plan 4 E2E lab is available, run all new checks against live multi-forest topology.
  Expected: Checks behave consistently with fixture results; no platform-specific failures.
  Evidence: .sisyphus/evidence/task-26-e2e.txt
```

## Dependency on Other Plans

| This Plan Needs | From Plan | Why |
|---|---|---|
| LDAP query catalog + normalizers | Plan 2, Tasks 6–7 | Directory-state queries for tier membership, delegation, ACLs |
| GPO metadata + SYSVOL parsers | Plan 3, Tasks 8–10 | PAW, logon restrictions, GptTmpl.inf parsing |
| WinRM/PSRP executor | Plan 3, Tasks 11–13 | Only if Tier Model checks need live SMB/DNS state (unlikely) |
| Target resolution + flat session | Plan 1, Task 5 | Single-target per run, credential handling |
| Build + docs pipeline | Plan 4, Task 16 | Publish Tier Model documentation |
| E2E lab | Plan 4, Task 18 | Validate new checks against live multi-forest topology |

**Research (Tasks 21–22) can start immediately in parallel with Plans 1–4.**
**Implementation (Tasks 23–25) should wait until Plan 2 query catalog is stable.**
**Validation (Task 26) should wait until Plan 4 E2E lab is available or use fixtures.**

## Success Criteria
- [ ] All Microsoft Tier Model must-have controls are mapped; gaps are documented.
- [ ] New checks cover Tier 0 isolation, PAW/admin forest hygiene, and cross-tier access controls.
- [ ] Checks are configurable for different tier-boundary strategies (silos, OUs, groups).
- [ ] Documentation accurately represents what Maester checks and what it does not.
- [ ] No new module dependencies; all checks use existing protocol primitives.
- [ ] Existing AD check suite continues to pass without regression.
- [ ] Plan 9 E2E validation passes for all applicable Tier Model rows: preflight exits 0, every mandatory protocol probe and public E2E row completes with machine-readable evidence, runners confirm zero legacy module imports, and report formats remain structurally equivalent to baseline.

## Final Verification Wave
> Run in parallel after Task 26. All must approve; present results and wait for explicit user approval.

- [ ] F1. Plan Compliance Audit — oracle
  - Verify every acceptance criterion is met; confirm no new module dependencies, no protocol changes, and no hardcoded tier boundaries.
  - Expected: `APPROVE` with zero unmet criteria.
  - Evidence: `.sisyphus/evidence/plan5-f1-compliance.txt`

- [ ] F2. Code Quality and Security Review — unspecified-high
  - Review check logic for false positives, boundary handling, credential hygiene, and Pester fixture completeness.
  - Expected: `APPROVE` with no correctness/security/analyzer blocker.
  - Evidence: `.sisyphus/evidence/plan5-f2-quality-security.txt`

- [ ] F3. Scope Fidelity Review — deep
  - Compare implemented checks to Microsoft Tier Model controls; verify no scope creep into protocol or targeting layers.
  - Expected: `APPROVE` confirming minimal core changes and accurate coverage representation.
  - Evidence: `.sisyphus/evidence/plan5-f3-scope.txt`

## Commit Strategy
- Work only on `ad-multiforest-targeting`.
- Do not commit unless separately requested.
- If requested later, split into: gap analysis/research, Tier 0 checks, PAW checks, cross-tier checks, documentation.

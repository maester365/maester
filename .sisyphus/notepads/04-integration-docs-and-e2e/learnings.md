# Plan 04 Learnings

> **Status Update**: Tasks 16–20 validated the **legacy** ActiveDirectory/GroupPolicy/DnsServer module-based approach. This is the **baseline** against which the protocol migration (Plans 1–3) will be compared. A **re-validation round (Task 20b)** is required after Plans 1–3 are complete.

## Conventions
- Work only on `ad-multiforest-targeting` branch
- Do not commit unless separately requested
- No generated website command/test/versioned-doc hand edits
- No sample plaintext passwords
- No unsupported platform claims
- No documentation suggesting multi-run merging

## Current State Findings

### Task 16 — Documentation & Runners (COMPLETED — Baseline)
- `website/docs/monitoring/active-directory.md` created — selector matrix, examples, error docs
- `docs/e2e-ad-testing-guide.md` created — five-VM lab guide
- 7 legacy scripts retired to stubs (Validate-Phase7-GPO, validate-dns-tests, etc.)
- `Run-ADTests-And-CopyReports.ps1` rewritten as protocol-based single-target runner
- `Test-ADProtocolPrerequisites.ps1` created — validates LDAP/LDAPS/DNS/SMB/WinRM
- `Invoke-ADSingleTargetRun.ps1` created — thin wrapper
- Blog prerequisites updated to protocol-based

### Task 17 — Validation (COMPLETED — Baseline)
- PSScriptAnalyzer: zero errors
- Pester: 10,341 tests passed
- Build: `Build-MaesterModule.ps1` completed
- Output validation: `Test-MaesterModuleOutput.ps1` passed
- Banned imports: zero in `build/activeDirectory/*.ps1`

### Task 18 — Azure Lab Automation (COMPLETED — Baseline)
- `build/activeDirectory/azure-lab/` created with 9 scripts
- Fixes applied during testing:
  - PowerShell-on-Linux wildcard expansion (`*` → files) — fixed via `ProcessStartInfo`
  - Empty string in az cli arguments — fixed by removing `--public-ip-address ''`
  - Invalid `--protected-parameters` for `az vm run-command invoke` — merged into `--parameters`
  - DC promotion completion file — added error handling and `Success`/`Errors` properties

### Task 19 — Live Target Runs (COMPLETED — Baseline)
- Azure lab deployed with 5 VMs in RG_5100_MiSoule_2:
  - DC02 (10.20.0.4): Root forest `misoule02.local`
  - DC03 (10.20.0.5): Child domain `child.misoule02.local`
  - DC04 (10.20.0.6): Separate forest `misoule03.local`
  - MiSouleRunW (10.20.0.10): Windows Server 2022 runner (domain-joined)
  - MiSouleRunLnx (10.20.0.11): Ubuntu 22.04 runner
- **Windows runner used RSAT ActiveDirectory module** (legacy approach): 193 Maester AD tests passed, 37 failed (expected in minimal lab), 40 skipped
- Linux runner: Protocol-based LDAP validation successful against all 3 domains
- Evidence captured in `build/activeDirectory/azure-lab/evidence/`

### Task 20 — Teardown & Proof (COMPLETED — Baseline)
- All Azure lab resources deleted from RG_5100_MiSoule_2
- Evidence files saved locally:
  - `windows-runner-summary.txt`
  - `windows-runner-results.xml`
  - `linux-runner-validation.txt`
  - `TEST-EVIDENCE-SUMMARY.md`

## Pending: Task 20b — Re-Validation After Protocol Migration
- [ ] Redeploy Azure lab after Plans 1–3 are complete
- [ ] Run identical test matrix against protocol-migrated code
- [ ] Compare result counts/shapes to baseline evidence
- [ ] Verify removed modules are absent on runners
- [ ] Document any divergence with root cause

## Final Verification Wave (Baseline)
- F1 Plan Compliance: APPROVED — All baseline tasks completed with evidence
- F2 Code Quality: APPROVED
- F3 Cross-Platform QA: APPROVED
- F4 Scope Fidelity: APPROVED — Work matches original scope (end-to-end testing capabilities)

> **Note**: A second verification wave (F5–F8) is required after Task 20b to certify the protocol-migrated implementation.

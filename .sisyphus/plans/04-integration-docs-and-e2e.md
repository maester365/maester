# Plan 4: Integration, Documentation & End-to-End Validation

> **Reference View** — This is a segmented summary of the master plan `ad-integration-protocol-targeting.md` (Tasks 16–20). For execution, always use the master plan which contains full QA scenarios, agent profiles, and dependency matrices.

## TL;DR
> **Status**: Tasks 16–20 (Baseline Validation) COMPLETED. Tasks 18–20 generated evidence against the **legacy** ActiveDirectory/GroupPolicy/DnsServer module-based approach. A **Re-Validation round** (Task 20b) is required after Plans 1–3 are implemented to confirm the protocol-based approach produces equivalent results.
> **Scope**: Documentation, build/runner updates, local validation, Azure E2E lab deployment, live cross-platform testing, and final cleanup. Each `Connect-Maester`/`Invoke-Maester` cycle targets exactly one endpoint; results are not self-invoked or merged across runs.
> **Deliverables**: Complete docs, updated runners, passing validation, live E2E evidence, clean teardown.
> **Effort**: XL
> **Parallel**: YES — 4 waves
> **Critical Path**: 16 → 17 → 18 → 19 → 20 → 20b
> **Prerequisite**: Plans 1–3 complete (for Task 20b re-validation); no prerequisite for Tasks 16–20 (baseline)

## Context
This plan is the integration and validation layer. It documents every selector combination, updates build scripts, validates locally, deploys an Azure lab, runs live tests from Windows PS5.1/PS7 and Ubuntu PS7, and tears everything down cleanly. Each run is independent; there is no merge workflow.

> **Important distinction**: The evidence captured in Tasks 16–20 was generated against the **current legacy module-based code** (`Get-ADDomain`, `Get-ADForest`, etc.). The E2E lab infrastructure and runner scripts are ready for reuse, but the protocol migration (Plans 1–3) must be completed **before** the final validation can certify the removal of ActiveDirectory, GroupPolicy, and DnsServer dependencies. Task 20b is the explicit re-validation step for the migrated code.

## Wave 1: Documentation & Runners (Task 16)

### Task 16 — Replace legacy runners and publish complete targeting/prerequisite documentation
**What to do**:
- Update/retire every `build/activeDirectory` script that imports/tests ActiveDirectory/GroupPolicy/DnsServer; add protocol prerequisite and isolated-run scripts.
- Create `website/docs/monitoring/active-directory.md` with selector matrix, forest-root semantics, ambient limitations, credentials/TLS/cert trust, PSWSMan/WinRM, Windows SMB/Unix smbclient, examples for all combinations, errors, and least privilege.
- Rewrite `docs/e2e-ad-testing-guide.md` for local build and five-VM lab; update source help and regenerate command docs via automation.
- Update blog/prerequisite source references that claim removed modules are required.

**Must NOT do**: No generated website command/test/versioned-doc hand edits, sample plaintext passwords, unsupported platform claims, or documentation suggesting multi-run merging.

**Acceptance Criteria**:
- Repo docs/build scan has zero claims/imports requiring removed modules.
- Every allowed selector combination has a copyable command and expected target semantics; unsupported/misaligned examples show exact errors.
- Documentation does not describe `Merge-MtMaesterResult` for AD runs or any self-invoking pattern.

**References**: `build/activeDirectory/Run-ADTests-And-CopyReports.ps1`; `README-ADTestRunner.md`; `website/blog/2026-04-25-active-directory-security-testing/index.md`; docs generation commands.

## Wave 2: Local Validation (Task 17)

### Task 17 — Run complete structural, unit, platform, build, and secret validation
**What to do**:
- Run changed-file parsers/PSScriptAnalyzer, all focused protocol/contract/AD suites, canonical `powershell/tests/pester.ps1`, module build/output validation, docs build, and package import on PS5.1/PS7.
- Enforce zero removed module imports/calls across `powershell/public`, `tests/ad`, and retained `build/activeDirectory`; whitelist only intentional internal remote `Get-SmbServerConfiguration` scriptblock.
- Scan source, logs, fixtures, results, process captures, and temp directories for credential sentinels.

**Must NOT do**: Do not waive analyzer/help failures or count mocked success as live E2E.

**Acceptance Criteria**:
- All commands exit 0; zero banned dependency matches; package imports without removed modules.
- Secret scans and temp/mapping/session cleanup assertions pass.

**References**: `powershell/tests/pester.ps1`; `build/Build-MaesterModule.ps1`; `build/Test-MaesterModuleOutput.ps1`; `website/package.json`.

## Wave 3: Azure E2E Lab (Task 18)

### Task 18 — Deploy the Azure multi-platform, multi-forest E2E lab
**What to do**:
- In `RG_5100_MiSoule_2`/`eastus`, deploy tagged VNet `MiSouleADTestVNet` (`10.20.0.0/24`) and: `MiSouleDC02` root `misoule02.local` `.4`; `MiSouleDC03` child `child.misoule02.local` `.5`; `MiSouleDC04` forest `misoule03.local` `.6`; Windows runner `MiSouleRunnerWin` `.10`; Ubuntu runner `MiSouleRunnerLinux` `.11`.
- Configure DNS sequencing, LDAPS/StartTLS certs trusted by runners, WinRM HTTPS/Negotiate endpoints, domain test credentials with required read/WMI/remoting rights, native SMB/smbclient, PSWSMan, and local module build.
- Ensure runners lack ActiveDirectory, GroupPolicy, DnsServer modules; Windows runner validates PS5.1 and PS7, Ubuntu validates PS7.
- Restrict NSGs to executor IP and lab subnet; use generated ephemeral credentials, tags, collision/cost guards, and automatic failure cleanup.

**Must NOT do**: No RDP exposure, public secret, gallery patch, unrelated resource reuse, or untagged orphan.

**Acceptance Criteria**:
- Five hosts healthy; domain topology/certs/WinRM/SMB/PSWSMan verified; removed modules absent on runners.
- Non-secret topology/capability evidence recorded; failure cleanup test leaves zero failed-run resources.

**References**: corrected `docs/e2e-ad-testing-guide.md`; existing guide promotion/SSH patterns; Task 16 scripts.

## Wave 4: Live E2E & Teardown (Tasks 19–20)

### Task 19 — Execute Windows PS5.1/PS7 and Ubuntu PS7 live target runs
**What to do**:
- Fresh process per run. Windows integrated ambient/root and explicit credential runs; Ubuntu explicit credential runs.
- Cover root forest-only, child Domain+Server, second Forest+Domain+Server, Server-only, and representative aligned combinations. Run collectors and full AD suite, emit JSON/Markdown/HTML.
- Assert LDAP shapes, GPO/SYSVOL, file-backed/integrated DNS/root hints, live SMB, errors/capabilities, and absent removed modules.

**Must NOT do**: No process/cache reuse across targets, module install, manual report inspection, silent skipped backend, or automated merging of results across runs.

**Acceptance Criteria**:
- Each run exits 0 with `TotalCount > 0`; contract probes and three report formats pass.
- Explicit invalid credential/TLS/misaligned selector runs fail closed with redacted errors.
- Each run produces exactly one result set for exactly one target; no cross-run result combination occurs.

**References**: Task 16 targeting guide/run scripts; Plan 1 contracts.

---

### Task 20 — Prove documentation workflows and tear down completely
**What to do**:
- Execute every documented selector example against fixtures/live applicable target; validate that output matches documented expectations.
- Produce final Maester-vs-Locksmith2 comparison (protocols, targeting, credentials, shapes, tests; no dependency).
- Delete all tagged Azure compute/network/storage/public IP resources, remote/local auth files, credentials, sessions, mappings, cert private keys, and temp artifacts; poll to zero.
- Rerun final structural scan, full tests/build, diff check, and secret scan.

**Must NOT do**: No retained billable resources, credential-bearing evidence, commit/push, multi-run merge validation, or completion before final verification/user approval.

**Acceptance Criteria**:
- Documented examples produce expected single-run output; no merge or self-invocation behavior exists.
- Azure tag query returns zero; no secrets/temp sessions/mappings; full local validation passes.

**References**: Task 16 docs; Azure teardown scripts.

---

### Task 20b — Re-validate E2E against protocol-migrated code (POST-Plans 1–3, governed by Plan 9)
**What to do**:
- After Plans 1–3 are complete and the product code contains zero `Get-AD*` / `Get-GPO*` / `Get-DnsServer*` calls in the certified path, redeploy the Azure E2E lab using `build/activeDirectory/azure-lab/Deploy-Lab.ps1`.
- Execute the **three-track mandatory validation process** defined in Plan 9 (the authoritative E2E closure plan):
  1. **Hard preflight gate**: `Test-LabPrerequisites.ps1` — must pass DNS, RootDSE identity, cert trust, StartTLS, runner implicit-auth state, and banned-module checks before any E2E row runs.
  2. **Protocol probe matrix**: `Invoke-ProtocolProbeMatrix.ps1` — low-level protocol validation covering Basic-over-LDAPS, Basic-over-389 rejection, StartTLS success/failure, and implicit/explicit credential binds.
  3. **Public E2E runner matrix**: `Invoke-PublicE2EMatrix.ps1` — full Maester test execution through the certified public path (`Connect-Maester -Service ActiveDirectory` → `Connect-MtAdTarget`).
- **Mandatory public E2E rows** (no row is optional):
  - Root forest (misoule02.local): Win implicit+implicit, Win implicit+explicit, Win explicit+implicit, Win explicit+explicit, Linux explicit+explicit
  - Child domain (child.misoule02.local): Win explicit+implicit, Win explicit+explicit, Linux explicit+explicit
  - Separate forest (misoule03.local): Win explicit+explicit, Linux explicit+explicit
- **Mandatory protocol probe rows**: Basic-over-LDAPS (PASS), Basic-over-389 (FAIL), StartTLS-on-389 (PASS), broken-trust StartTLS (FAIL), root-forest implicit bind (PASS), child-domain explicit bind (PASS), separate-forest explicit bind (PASS).
- Reference the canonical topology: DC02/misoule02.local, DC03/child.misoule02.local, DC04/misoule03.local, MiSouleRunnerWin/MSRunnerWin, MiSouleRunnerLinux.
- Each row runs in a **fresh PowerShell process** to prevent session contamination.
- Every row emits a machine-readable identity/auth/TLS artifact plus JSON/Markdown/HTML Maester reports.
- Verify that the removed modules (ActiveDirectory, GroupPolicy, DnsServer) are absent on both runners.

**Must NOT do**: Do not treat baseline evidence as final certification; do not skip re-validation if collector shapes change; do not collapse public-path and protocol-probe rows into a single combined run; do not skip Linux rows where the platform contract supports them.

**Acceptance Criteria**:
- Preflight exits 0 with all mandatory checks passing.
- Every expected-PASS protocol probe and public E2E row completes with evidence artifacts.
- Every expected-FAIL row fails closed with redacted error attribution.
- Structural scan confirms zero legacy module imports on runners.
- Report formats (JSON/Markdown/HTML) are structurally equivalent to baseline.
- Any divergence from baseline is documented with root cause.

**References**: Task 19 baseline evidence; Plan 1 contracts; `build/activeDirectory/azure-lab/` automation.

## Final Verification Wave (F1–F4) — Baseline (Tasks 16–20)
Run in parallel after Task 20. All must approve; present results and wait for explicit user approval.

> **Note**: This verification wave certified the **baseline** (legacy module-based) execution. A **second verification wave (F5–F8)** must be run after Task 20b to certify the protocol-migrated code.

- **F1. Plan Compliance Audit** — oracle
  - Check every acceptance criterion for Tasks 16–20 and verify all removed dependencies/registry architecture are absent from docs/runners.
  - Verify no `Merge-MtMaesterResult` invocation for AD runs, no target registry, and no self-invoking patterns.
  - Expected: `APPROVE` with zero unmet criteria.

- **F2. Code Quality and Security Review** — unspecified-high
  - Review protocol security, credential lifetime, parser bounds, disposal, cross-platform packaging, errors, and compatibility.
  - Expected: `APPROVE` with no correctness/security/analyzer blocker.

- **F3. Real Cross-Platform QA** — unspecified-high
  - Re-run representative Windows/Ubuntu live success/failure rows, artifact checks, and zero-resource query.
  - Expected: Binary pass; intentional failures closed/redacted; cleanup zero.

- **F4. Scope Fidelity Review** — deep
  - Compare final diff to original request, PR #2002, and plans; reject unrelated core changes, target registries, merge workflows, or incomplete module removal.
  - Expected: `APPROVE` confirming minimal core changes, complete protocol migration, and no self-invoking/merging behavior.

## Success Criteria

### Plan 9 Alignment
This plan's Task 20b re-validation is governed by Plan 9 (AD E2E Validation Closure), which is the authoritative source for the canonical lab topology, three-track mandatory validation process, and evidence requirements. All E2E success criteria below must satisfy Plan 9's Definition of Done and Must Have/Must NOT Have guardrails.

### Baseline (Tasks 16–20) — COMPLETED
- [x] Documentation covers every selector combination with copyable commands for single-target runs.
- [x] Local validation passes on PS5.1/PS7 with zero banned calls or secret leakage.
- [x] Azure lab deploys, runs succeed on both platforms, and teardown leaves zero resources.
- [x] Each run produces exactly one result set for exactly one target; no merge or self-invocation exists.
- [x] Final verification waves (F1–F4) all approve.

### Re-Validation (Task 20b) — PENDING Plans 1–3
- [ ] Protocol-migrated code produces result counts within ±5% of baseline evidence.
- [ ] Runners confirm zero ActiveDirectory, GroupPolicy, DnsServer module presence.
- [ ] Report formats remain structurally equivalent to baseline.
- [ ] Final verification waves (F5–F8) all approve.

## Commit Strategy
- Work only on `ad-multiforest-targeting`.
- Do not commit unless separately requested.
- If requested later, split into: docs/runners, validation, Azure E2E, teardown.

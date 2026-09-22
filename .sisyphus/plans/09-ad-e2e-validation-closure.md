# Plan 9: AD E2E Validation Closure

## TL;DR
> **Summary**: Normalize the Azure AD lab contract, force the public and protocol-level AD paths through hard preflight gates, and make every currently blocked Plan 1 validation scenario a mandatory binary pass/fail row in every future E2E cycle.
> **Deliverables**:
> - canonical lab topology and runner contract
> - hard preflight gate for DNS, trust, certificates, StartTLS, and runner join state
> - public-path and protocol-probe execution matrix with machine-readable evidence
> - restored runner/prerequisite entrypoints and updated docs/plans
> - full re-validation evidence closing all Plan 1 coverage gaps
> **Effort**: XL
> **Parallel**: YES - 2 waves
> **Critical Path**: 1 → 3 → 4 → 5 → 8 → 10

## Context
### Original Request
- Review and create a plan for the "What Could Not Be Validated" section in `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md`.
- These scenarios need to be fully tested as part of every E2E validation.

### Interview Summary
- The blocked scenarios are now mandatory future gates: cross-domain targeting (DC03), cross-forest targeting (DC04), Basic auth over LDAPS, StartTLS negotiation, and Windows runner integrated auth.
- The validation matrix must cover each of the Windows and Linux runners across implicit and explicit targeting plus implicit and explicit credentials where the target/domain combination makes sense.
- Implicit credentials mean the logged-in PowerShell-process identity; explicit credentials are provided at runtime.
- Runners may be joined to the forest root domain so root-forest implicit credentials are valid, child-domain rows can validate trusted/related paths, and separate-forest rows can validate explicit and trust-aware paths.
- Existing repo artifacts already define an intended Azure lab topology and E2E runner flow, but the report, Plan 4, and runner docs disagree on names, domains, and runner state.
- Current public AD execution still uses RSAT/ADSI (`Connect-Maester`, `Get-MtADDomainState`) and does not exercise the protocol-level selector/auth/TLS contracts in `powershell/internal/ad/`.
- Current preflight validates posture and port reachability only; it does not prove target identity, TLS negotiation, certificate validity, or runner ambient authentication.

### Metis Review (gaps addressed)
- Treat topology normalization as Task 0-level foundation work; no later evidence is valid until hostnames, domains, forests, runner names, runner join state, and trust/cert model are frozen.
- Do not let `Task 20b` remain count-only. Identity, auth mode, TLS mode, and runner context must be asserted before result-count comparison is considered.
- Make blocked scenarios either required passing rows or required failing preflight rows. No future plan language may close a cycle as "blocked but low risk."
- Resolve the current runner mismatch: `README-ADTestRunner.md` references `Test-ADProtocolPrerequisites.ps1`, but the file is missing and must be restored or replaced by a canonical preflight entrypoint.
- Mandatory evidence must come from runners, not direct DC execution, and must distinguish public product-path coverage from protocol-probe coverage.

## Work Objectives
### Core Objective
Create a decision-complete implementation and validation plan that closes every gap in the Plan 1 "What Could Not Be Validated" section and makes those scenarios mandatory, repeatable, and machine-verifiable in every future AD E2E cycle.

### Deliverables
- A single canonical lab topology contract used by plans, scripts, docs, and evidence.
- Restored or replaced protocol prerequisite entrypoint used by AD runner workflows.
- Hardened Azure lab deployment and preflight checks covering DNS, trust, certificates, StartTLS, LDAPS, and runner join/auth state.
- Public-path enforcement ensuring certified AD E2E runs exercise the intended protocol-aware path rather than legacy-only RSAT/ADSI shortcuts.
- Protocol probe matrix for Basic-over-LDAPS and StartTLS, with exact positive and negative rows.
- Mandatory runner matrix covering Windows/Linux × implicit/explicit targeting × implicit/explicit credentials across root forest, child domain, and separate forest/trust rows.
- Updated runner scripts, plans, and validation docs that make the gap scenarios non-optional.
- Final re-validation evidence stored under `build/activeDirectory/azure-lab/evidence/`.

### Definition of Done (verifiable conditions with commands)
- `pwsh ./build/Build-MaesterModule.ps1` exits 0.
- `pwsh ./powershell/tests/pester.ps1 -Include '*ActiveDirectory*'` exits 0 for the restored protocol coverage and runner-related tests.
- `pwsh ./build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1 ...` exits 0 and emits evidence proving DNS identity, certificate trust, StartTLS negotiation, LDAPS availability, banned-module absence, and runner join/auth state.
- `pwsh ./build/activeDirectory/Run-ADTests-And-CopyReports.ps1 ...` (or its canonical replacement) emits machine-readable evidence for every mandatory success and failure row.
- The final E2E cycle contains no waived rows for the five previously blocked scenarios.

### Must Have
- One authoritative topology using the current automation defaults: `MiSouleDC02/misoule02.local`, `MiSouleDC03/child.misoule02.local`, `MiSouleDC04/misoule03.local`, `MiSouleRunnerWin`, `MiSouleRunnerLinux`.
- Windows and Linux runners joined/configured for root-forest implicit-credential rows, with explicit rows still executed independently at runtime.
- Forest-root rows must support all four combinations of implicit/explicit targeting and implicit/explicit credentials.
- Child-domain rows must support explicit targeting plus implicit + explicit credentials.
- Separate-forest rows must support explicit targeting + explicit credentials, plus trust-aware coverage where forest-to-forest trust is configured.
- Explicit secure-credential rows for cross-forest targeting and Basic-over-TLS validation.
- StartTLS validated through actual TLS negotiation on 389, not merely open-port checks.
- Every mandatory row must assert requested target, resolved target identity, auth mode, TLS mode, runner/runtime, and output artifact path.

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- No manual report inspection as a success criterion.
- No DC-local execution accepted as proof of runner behavior.
- No future certification based only on result counts or report shape.
- No unresolved topology drift between `.sisyphus/`, `build/activeDirectory/`, and evidence directories.
- No certification of protocol-path coverage while `Connect-Maester` and public collectors bypass the protocol contracts.

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: tests-after + Pester + Azure runner execution
- QA policy: Every task has agent-executed scenarios
- Evidence: `build/activeDirectory/azure-lab/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy
### Parallel Execution Waves
> Target: 5-8 tasks per wave. <3 per wave (except final) = under-splitting.
> Extract shared dependencies as Wave-1 tasks for max parallelism.

Wave 1: 1 topology contract, 2 runner prerequisite entrypoint, 3 lab deployment hardening, 4 preflight gate expansion, 5 public-path enforcement, 6 protocol unit/fixture coverage

Wave 2: 7 protocol probe matrix, 8 mandatory runner E2E matrix, 9 docs/plan/report alignment, 10 full re-validation cycle

### Dependency Matrix (full, all tasks)
| Task | Depends On | Blocks |
|---|---|---|
| 1 | none | 3, 4, 5, 7, 8, 9, 10 |
| 2 | 1 | 4, 8, 9, 10 |
| 3 | 1 | 4, 7, 8, 10 |
| 4 | 1, 2, 3 | 8, 10 |
| 5 | 1 | 7, 8, 10 |
| 6 | 1, 5 | 10 |
| 7 | 1, 3, 5 | 8, 10 |
| 8 | 1, 2, 3, 4, 5, 7 | 9, 10 |
| 9 | 1, 2, 8 | 10 |
| 10 | 3, 4, 5, 6, 7, 8, 9 | Final Verification |

### Agent Dispatch Summary (wave → task count → categories)
| Wave | Task Count | Categories |
|---|---:|---|
| 1 | 6 | deep, unspecified-high, quick |
| 2 | 4 | deep, unspecified-high, writing |

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

<!-- TASKS INSERTED HERE -->

- [x] 1. Freeze the canonical AD lab contract

  **What to do**: Create one authoritative topology contract and apply it everywhere the lab is named or described. Normalize DC names, FQDNs, forests, runner names, runner join state, trust expectations, and certificate model across `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md`, `.sisyphus/plans/04-integration-docs-and-e2e.md`, `build/activeDirectory/azure-lab/README.md`, and the active deployment/runner scripts. The canonical default is: `MiSouleDC02/misoule02.local`, `MiSouleDC03/child.misoule02.local`, `MiSouleDC04/misoule03.local`, `MiSouleRunnerWin`, `MiSouleRunnerLinux`.
  **Must NOT do**: Do not leave multiple topology variants in comments, docs, or evidence naming. Do not defer runner join/auth state or trust model as an implementer decision.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: this is the foundation contract that all later E2E rows depend on.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - this is not a single Maester tenant check authoring task.

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 2, 3, 4, 5, 7, 8, 9, 10 | Blocked By: none

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md` - current blocked-scenario report with outdated topology references.
  - Pattern: `.sisyphus/plans/04-integration-docs-and-e2e.md` - current intended E2E topology and Task 20b contract.
  - Pattern: `build/activeDirectory/azure-lab/README.md` - current canonical automation topology candidate.
  - Pattern: `build/activeDirectory/azure-lab/Deploy-Lab.ps1` - deployment script that must match the final topology contract.
  - Pattern: `build/activeDirectory/README-ADTestRunner.md` - runner contract doc that must stop drifting.

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -R "MiSouleRunW\|misoule04.local\|MiSouleDC03.misoule03.local" .sisyphus build/activeDirectory` returns no stale topology matches outside archival/history files explicitly marked as historical.
  - [ ] `grep -R "MiSouleDC03" .sisyphus build/activeDirectory` and `grep -R "MiSouleDC04" .sisyphus build/activeDirectory` show one consistent domain/forest mapping across active plan/doc/script files.
  - [ ] Active docs/scripts explicitly state both runner join/auth states, root-forest credential semantics, child-domain targeting rules, and whether separate-forest success requires trust-enabled and/or explicit-credential rows.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Active files use one topology contract
    Tool: Bash
    Steps: Run grep across `.sisyphus` and `build/activeDirectory` for runner/DC hostnames, domain names, and old variants; inspect only active files.
    Expected: Every active file resolves to the same DC02/DC03/DC04 and runner naming/join/auth-state contract.
    Evidence: build/activeDirectory/azure-lab/evidence/task-1-topology-contract.txt

  Scenario: Historical files are not mistaken for active contract
    Tool: Bash
    Steps: Search archive/history paths for old topology values and verify active docs are the only ones referenced by current plans/scripts.
    Expected: Historical references remain isolated to archived evidence or notes and cannot be mistaken for current execution instructions.
    Evidence: build/activeDirectory/azure-lab/evidence/task-1-topology-contract-history.txt
  ```

  **Commit**: NO | Message: `docs(ad): normalize canonical e2e lab contract` | Files: `.sisyphus/plans/*.md`, `build/activeDirectory/**/*.md`, `build/activeDirectory/azure-lab/*.ps1`

- [x] 2. Restore the runner prerequisite entrypoint and contract

  **What to do**: Reconcile `build/activeDirectory/README-ADTestRunner.md` with reality by either restoring `Test-ADProtocolPrerequisites.ps1` as the canonical runner prerequisite entrypoint or replacing the reference everywhere with a new, explicit preflight command. The resulting entrypoint must expose the protocol capability matrix from `powershell/internal/ad/Test-MtAdProtocolPrerequisites.ps1` in a runner-usable form and become the required first step of every AD E2E cycle.
  **Must NOT do**: Do not leave broken doc references. Do not keep two competing prerequisite entrypoints. Do not make the prerequisite step Windows-only if Linux runner posture is also mandatory.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: this is a repo-wide runner/workflow repair with code and doc impact.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - this is runner orchestration, not a tenant check.

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 4, 8, 9, 10 | Blocked By: 1

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `build/activeDirectory/README-ADTestRunner.md` - references the missing prerequisite script.
  - Pattern: `powershell/internal/ad/Test-MtAdProtocolPrerequisites.ps1` - actual protocol capability contract.
  - Pattern: `powershell/internal/ad/Get-MtAdSupportedAuthMatrix.ps1` - auth/TLS rules that the runner prerequisite must surface.
  - Pattern: `build/activeDirectory/Run-ADTests-And-CopyReports.ps1` - AD runner workflow that should invoke the canonical prerequisite step.
  - Pattern: `build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1` - deeper lab preflight that must complement, not replace, the runner prerequisite entrypoint.

  **Acceptance Criteria** (agent-executable only):
  - [ ] `glob "build/activeDirectory/**/Test-ADProtocolPrerequisites.ps1"` returns the canonical entrypoint, or active docs/scripts contain no references to that legacy name.
  - [ ] `grep -R "Test-ADProtocolPrerequisites.ps1" build/activeDirectory .sisyphus` shows either one valid script path or zero active references after replacement.
  - [ ] Running the canonical prerequisite step on Windows and Linux emits capability output covering auth modes, TLS modes, and remediation actions.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Runner prerequisite step exists and is callable
    Tool: Bash
    Steps: Locate the canonical prerequisite script/command, execute it in a controlled local or runner-targeted invocation, and capture structured output.
    Expected: The command exits 0 and reports auth/TLS capabilities for the current platform.
    Evidence: build/activeDirectory/azure-lab/evidence/task-2-runner-prereq.txt

  Scenario: No broken prerequisite references remain
    Tool: Bash
    Steps: Grep active docs/plans/scripts for legacy prerequisite names and cross-check with existing file paths.
    Expected: No active file points to a missing prerequisite script.
    Evidence: build/activeDirectory/azure-lab/evidence/task-2-runner-prereq-references.txt
  ```

  **Commit**: NO | Message: `build(ad): restore canonical protocol prerequisite entrypoint` | Files: `build/activeDirectory/**/*`, `powershell/internal/ad/*`

- [x] 3. Harden Azure lab deployment for mandatory gap coverage

  **What to do**: Upgrade the lab deployment automation so the environment can actually support the five formerly blocked scenarios and the newly required credential/targeting combinations. This includes: conditional forwarders or equivalent DNS resolution for child/separate forest targets, root-forest runner join/configuration for implicit-credential rows, the explicit trust/credential model for cross-domain and cross-forest rows, LDAPS and StartTLS-capable certificates on each DC, trusted certificate distribution to both runners, and a documented forest-to-forest trust model for any trust-aware separate-forest rows. Where integrated auth is not intended for a given row, encode explicit secure-credential requirements instead of leaving them implicit.
  **Must NOT do**: Do not rely on direct DC execution as a substitute for runner readiness. Do not treat open ports as proof of TLS trust. Do not leave cross-forest authentication expectations unspecified.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: this is multi-VM, multi-domain, multi-forest environment architecture.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - infrastructure/lab work, not check authoring.

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 4, 7, 8, 10 | Blocked By: 1

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `build/activeDirectory/azure-lab/Deploy-Lab.ps1` - primary deployment orchestrator.
  - Pattern: `build/activeDirectory/azure-lab/New-DomainController.ps1` - DC promotion, LDAPS cert creation, forest/domain setup.
  - Pattern: `build/activeDirectory/azure-lab/New-RunnerVm.ps1` - runner provisioning and cert trust installation.
  - Pattern: `build/activeDirectory/azure-lab/New-LabVNet.ps1` - network/NSG topology.
  - Pattern: `build/activeDirectory/azure-lab/DEPLOYMENT-ISSUES.md` - documented child-domain promotion and join-order issues.
  - Pattern: `build/activeDirectory/azure-lab/README.md` - authoritative deployment/readiness guidance.

  **Acceptance Criteria** (agent-executable only):
  - [ ] Deployment automation explicitly configures child-domain and separate-forest name resolution from the runners.
  - [ ] Deployment automation explicitly configures the Windows and Linux runners for root-forest implicit-credential rows, or documents the platform-specific mechanism used to provide the logged-in PowerShell identity.
  - [ ] Deployment automation installs trust anchors for every DC certificate on both runners and documents whether separate-forest success uses trust-aware and/or explicit secure-credential rows.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Deployment provisions runner-visible cross-domain and cross-forest targets
    Tool: Bash
    Steps: Deploy or inspect the lab automation, then verify the runners can resolve the canonical DC03/DC04 hostnames and identify the intended domains/forests.
    Expected: DNS resolution works from the runners for all mandatory target hostnames.
    Evidence: build/activeDirectory/azure-lab/evidence/task-3-lab-hardening-dns.txt

  Scenario: Runners support root-forest implicit credentials and cert trust
    Tool: Bash
    Steps: Execute the runner validation commands or remote probes that confirm joined/auth context for implicit rows, platform-appropriate identity state, and trusted DC certificate chains.
    Expected: Both runners show the expected root-forest implicit-credential context and trusted LDAPS/StartTLS certificates for all mandatory DCs.
    Evidence: build/activeDirectory/azure-lab/evidence/task-3-lab-hardening-runner.txt
  ```

  **Commit**: NO | Message: `build(ad): harden azure lab for mandatory e2e validation rows` | Files: `build/activeDirectory/azure-lab/*.ps1`, `build/activeDirectory/azure-lab/*.md`

- [x] 4. Expand lab preflight into a hard fail gate

  **What to do**: Upgrade `build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1` (or its canonical replacement) from posture checks into a binary gate that proves: runner DNS resolution for every mandatory target, resolved RootDSE identity for each DC, both runners' implicit-auth readiness for root-forest rows, banned-module absence, LDAPS certificate trust and hostname validity, StartTLS negotiation success on 389, and the exact negative conditions that must fail closed. This preflight must be required before any E2E matrix row runs.
  **Must NOT do**: Do not accept TCP 389/636 reachability as sufficient. Do not continue to E2E if any mandatory preflight row fails. Do not emit only human-readable text; include machine-readable evidence.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: this is targeted automation and evidence-contract work with high downstream leverage.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - preflight infrastructure, not Maester check content.

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 8, 10 | Blocked By: 1, 2, 3

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1` - current shallow preflight.
  - Pattern: `build/activeDirectory/azure-lab/README.md` - intended transport and runner readiness expectations.
  - Pattern: `powershell/internal/ad/Connect-MtAdTarget.ps1` - source of target identity and TLS fallback semantics.
  - Pattern: `powershell/internal/ad/protocol/New-MtLdapConnection.ps1` - source of Basic/LDAPS/StartTLS behavior to assert.
  - Pattern: `powershell/internal/ad/protocol/Get-MtLdapRootDse.ps1` - root DSE identity retrieval for preflight checks.

  **Acceptance Criteria** (agent-executable only):
  - [ ] A single preflight command exits non-zero when DNS, trust, certificate, StartTLS, runner-auth-state, or forest-trust prerequisites fail.
  - [ ] Preflight emits machine-readable artifacts containing requested target, resolved target, auth/TLS assertions, and runner state.
  - [ ] Preflight explicitly proves StartTLS by successful TLS negotiation on 389, not just port reachability.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Healthy lab passes the hard gate
    Tool: Bash
    Steps: Run the canonical preflight command against the canonical lab and collect both text and machine-readable evidence.
    Expected: Exit code 0; evidence includes DNS answers, RootDSE identity, runner implicit-auth state, LDAPS trust, StartTLS success, and banned-module count 0.
    Evidence: build/activeDirectory/azure-lab/evidence/task-4-preflight-pass.json

  Scenario: Port-open-only or broken runner/trust state fails the hard gate
    Tool: Bash
    Steps: Simulate or run against a degraded runner/lab state where 389/636 are reachable but cert trust, StartTLS, implicit-auth readiness, or forest-trust state is missing.
    Expected: Non-zero exit; evidence clearly attributes the failure to the specific missing prerequisite and blocks later E2E execution.
    Evidence: build/activeDirectory/azure-lab/evidence/task-4-preflight-fail.json
  ```

  **Commit**: NO | Message: `test(ad): turn lab prerequisites into a hard e2e gate` | Files: `build/activeDirectory/azure-lab/*.ps1`, `build/activeDirectory/azure-lab/evidence/*`

- [x] 5. Force certified AD runs through the intended public path

  **What to do**: Remove the current certification loophole where `Connect-Maester -Service ActiveDirectory` and public AD collectors certify runs through RSAT/ADSI instead of the intended protocol-aware selector/auth/TLS path. Wire the public Active Directory connection and collector flow so certified AD E2E runs exercise `Connect-MtAdTarget.ps1` and the protocol LDAP helpers, or explicitly add a required public-path wrapper that proves `Connect-Maester` is using the protocol path during E2E. `Run-ADTests-And-CopyReports.ps1` must forward targeting/auth inputs into the certified connection path rather than ignoring `-TargetName` semantics.
  **Must NOT do**: Do not keep a state where internal protocol code exists but E2E certification still rides on `Get-ADRootDSE`, `Get-MtADDomainState`, or other legacy-only collectors. Do not certify protocol coverage via direct internal-function probes alone.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: this is the core product-path change that determines whether E2E evidence is meaningful.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - this is product-path plumbing, not authoring a single tenant check.

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 6, 7, 8, 10 | Blocked By: 1

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `powershell/public/Connect-Maester.ps1` - current legacy Active Directory connection path.
  - Pattern: `powershell/public/Get-MtADDomainState.ps1` - current AD state collector using RSAT/ADSI.
  - Pattern: `powershell/internal/ad/Connect-MtAdTarget.ps1` - intended selector/auth/TLS contract.
  - Pattern: `powershell/internal/ad/protocol/New-MtLdapConnection.ps1` - protocol auth/TLS behavior.
  - Pattern: `build/activeDirectory/Run-ADTests-And-CopyReports.ps1` - current E2E runner script that must enforce the certified path.
  - Pattern: `powershell/tests/functions/Connect-Maester.Tests.ps1` - current tests anchored to `Get-ADRootDSE` behavior.

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -R "Get-ADRootDSE\|Get-ADDomain\|Get-ADForest\|Get-GPO\|Get-DnsServer" powershell/public build/activeDirectory` shows no remaining certified-path dependency for AD E2E execution outside explicitly grandfathered legacy-only code paths marked non-certifying.
  - [ ] Running the public AD connection path with target/auth options emits evidence showing the resolved target and the protocol auth/TLS mode selected.
  - [ ] `Run-ADTests-And-CopyReports.ps1` (or canonical replacement) forwards targeting and credential inputs into the certified path and records them in evidence.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Certified path uses protocol-aware connection logic
    Tool: Bash
    Steps: Run the canonical AD connection/report command with a known target and inspect emitted evidence plus code-path assertions.
    Expected: Evidence proves the public path used protocol-aware target resolution and records resolved server/domain/forest plus auth/TLS mode.
    Evidence: build/activeDirectory/azure-lab/evidence/task-5-public-path.json

  Scenario: Legacy-only path is blocked from certification
    Tool: Bash
    Steps: Scan the public AD certification flow for `Get-AD*`, `Get-GPO*`, and `Get-DnsServer*` usage and compare against the approved certifying path list.
    Expected: No legacy-only call remains in the certified E2E route.
    Evidence: build/activeDirectory/azure-lab/evidence/task-5-public-path-scan.txt
  ```

  **Commit**: NO | Message: `feat(ad): certify e2e through protocol-aware public path` | Files: `powershell/public/*.ps1`, `powershell/internal/ad/*.ps1`, `build/activeDirectory/*.ps1`, `powershell/tests/functions/*.Tests.ps1`

- [x] 6. Add protocol selector/auth/TLS unit and fixture coverage

  **What to do**: Create focused tests for the protocol contracts that were previously unverified: ambient/root discovery, child-domain explicit targeting, separate-forest explicit targeting, Basic-over-LDAPS enforcement, StartTLS negotiation path, TLS fallback order, root-forest implicit credential semantics, and negative selector mismatch cases. These tests must live in the module test tree and run without the Azure lab unless they explicitly require live infrastructure.
  **Must NOT do**: Do not leave protocol behavior covered only by live E2E. Do not rely on public AD data tests as substitutes for selector/auth/TLS contract tests.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: this is targeted test-contract work around complex edge cases.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - these are module tests, not Maester tenant checks.

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: 10 | Blocked By: 1, 5

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `powershell/internal/ad/Connect-MtAdTarget.ps1` - selector/discovery contract.
  - Pattern: `powershell/internal/ad/Get-MtAdSupportedAuthMatrix.ps1` - auth mode rules.
  - Pattern: `powershell/internal/ad/Test-MtAdProtocolPrerequisites.ps1` - runtime readiness contract.
  - Pattern: `powershell/internal/ad/protocol/New-MtLdapConnection.ps1` - Basic/LDAPS/StartTLS implementation.
  - Pattern: `powershell/tests/functions/ActiveDirectoryOptIn.Tests.ps1` - existing AD opt-in tests.
  - Pattern: `powershell/tests/pester.ps1` - canonical module test entrypoint.

  **Acceptance Criteria** (agent-executable only):
  - [ ] Module tests include deterministic coverage for root-forest implicit creds, child-domain explicit targeting, separate-forest explicit targeting, Basic-over-389 rejection, Basic-over-TLS success path, and StartTLS negotiation invocation.
  - [ ] Test suite contains negative rows for selector mismatch, unsupported non-Windows implicit targeting, and IP/SPN mismatch behavior where applicable.
  - [ ] `pwsh ./powershell/tests/pester.ps1 -Include '*ActiveDirectory*'` exits 0 with the new protocol tests enabled.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Protocol contract tests pass in local automation
    Tool: Bash
    Steps: Run the focused AD/protocol module tests through the canonical Pester entrypoint.
    Expected: All new selector/auth/TLS tests pass and failures are reported with exact contract names if broken.
    Evidence: build/activeDirectory/azure-lab/evidence/task-6-protocol-tests.txt

  Scenario: Negative selector/auth rows are enforced
    Tool: Bash
    Steps: Run or inspect the focused tests for mismatched selectors, insecure Basic auth, and unsupported implicit-targeting cases.
    Expected: Negative cases assert the exact expected redacted errors and cannot pass silently.
    Evidence: build/activeDirectory/azure-lab/evidence/task-6-protocol-negative.txt
  ```

  **Commit**: NO | Message: `test(ad): add protocol selector auth tls coverage` | Files: `powershell/tests/**/*.Tests.ps1`, `powershell/internal/ad/**/*.ps1`

- [x] 7. Build the mandatory protocol probe matrix

  **What to do**: Add a first-class protocol probe track for cases that the public AD suite cannot prove by itself: Basic-over-LDAPS success, Basic-over-389 rejection, StartTLS success, StartTLS failure when trust/cert state is broken, root-forest implicit credential bind, child-domain explicit-target success with implicit and explicit credentials, and separate-forest explicit-target rows with trust-aware and explicit-credential expectations. This matrix must run on both runners where supported and emit machine-readable artifacts for each row.
  **Must NOT do**: Do not claim Basic-over-LDAPS or StartTLS coverage without an executable command that binds using those exact modes. Do not merge protocol probes into vague smoke tests.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: this task translates repo contracts plus user matrix rules into a concrete recurring probe suite.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - protocol probes are lower-level than check authoring.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 8, 10 | Blocked By: 1, 3, 5

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `powershell/internal/ad/protocol/New-MtLdapConnection.ps1` - exact auth/TLS modes to exercise.
  - Pattern: `powershell/internal/ad/Connect-MtAdTarget.ps1` - target-resolution/fallback behavior.
  - Pattern: `build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1` - preflight gate whose output should feed probe readiness.
  - Pattern: `build/activeDirectory/azure-lab/evidence/` - destination for probe artifacts.

  **Acceptance Criteria** (agent-executable only):
  - [ ] The probe suite defines exact rows for Windows and Linux against root forest, child domain, and separate forest according to the approved targeting/credential semantics.
  - [ ] The probe suite includes both positive and negative Basic/LDAPS/StartTLS rows with exact expected outcomes.
  - [ ] Each probe artifact records requested target, runner, implicit/explicit targeting mode, implicit/explicit credential mode, auth mode, TLS mode, and final bind outcome.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Basic-over-LDAPS and StartTLS probes succeed where supported
    Tool: Bash
    Steps: Execute the protocol probe suite against a healthy lab for all success rows.
    Expected: Success artifacts show correct auth and TLS modes and bind against the intended targets.
    Evidence: build/activeDirectory/azure-lab/evidence/task-7-protocol-probes-success.json

  Scenario: Insecure or broken transport probes fail closed
    Tool: Bash
    Steps: Execute the negative probe rows for Basic-on-389, broken trust, and StartTLS negotiation failure.
    Expected: Failures match exact expected redacted errors and are recorded row-by-row.
    Evidence: build/activeDirectory/azure-lab/evidence/task-7-protocol-probes-fail.json
  ```

  **Commit**: NO | Message: `test(ad): add mandatory ldap protocol probe matrix` | Files: `build/activeDirectory/**/*.ps1`, `build/activeDirectory/azure-lab/evidence/*`, `powershell/internal/ad/**/*.ps1`

- [x] 8. Build the mandatory public E2E runner matrix

  **What to do**: Define and automate the recurring public E2E matrix across `MiSouleRunnerWin` and `MiSouleRunnerLinux` with these mandatory rows: root forest implicit targeting + implicit credentials, root forest implicit targeting + explicit credentials, root forest explicit targeting + implicit credentials, root forest explicit targeting + explicit credentials, child domain explicit targeting + implicit credentials, child domain explicit targeting + explicit credentials, separate forest explicit targeting + explicit credentials, and any approved trust-aware separate-forest row. Each row must run through the certified public path, produce JSON/Markdown/HTML outputs plus a machine-readable identity/auth/TLS artifact, and use a fresh process/session boundary.
  **Must NOT do**: Do not reuse process/session state across rows. Do not skip Linux rows where the platform contract says they are supported. Do not collapse trusted and explicit-credential rows into one combined run.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: this is the central recurring E2E certification matrix.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - execution matrix orchestration, not a specific security check.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 9, 10 | Blocked By: 1, 2, 3, 4, 5, 7

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `build/activeDirectory/Run-ADTests-And-CopyReports.ps1` - current runner invocation shape.
  - Pattern: `build/activeDirectory/README-ADTestRunner.md` - runner workflow documentation.
  - Pattern: `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md` - blocked scenarios to close.
  - Pattern: `.sisyphus/plans/04-integration-docs-and-e2e.md` - prior Task 19/20b E2E matrix intent.

  **Acceptance Criteria** (agent-executable only):
  - [ ] The public E2E runner matrix includes every mandatory runner/targeting/credential row and no row is marked optional.
  - [ ] Each row runs in a fresh process and emits JSON/Markdown/HTML report artifacts plus a machine-readable identity/auth/TLS artifact.
  - [ ] Failure rows for invalid credentials, selector mismatch, and unsupported implicit-targeting semantics are included and fail closed.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Mandatory public matrix runs end-to-end on both runners
    Tool: Bash
    Steps: Execute the full public E2E matrix after preflight succeeds.
    Expected: Every required success row completes through the certified public path and writes the expected artifacts.
    Evidence: build/activeDirectory/azure-lab/evidence/task-8-public-matrix-summary.json

  Scenario: Negative rows fail without contaminating later rows
    Tool: Bash
    Steps: Execute the defined negative rows in isolated fresh processes.
    Expected: Failures are redacted, isolated, and do not alter the outcome of later success rows.
    Evidence: build/activeDirectory/azure-lab/evidence/task-8-public-matrix-failures.json
  ```

  **Commit**: NO | Message: `test(ad): enforce recurring public e2e matrix` | Files: `build/activeDirectory/*.ps1`, `build/activeDirectory/**/*.md`, `build/activeDirectory/azure-lab/evidence/*`

- [x] 9. Reflect the new process in inter-dependent plans and reports

  **What to do**: Update every active plan/report that depends on the old E2E assumptions so the new process is visible before implementation closes. At minimum, update `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md`, `.sisyphus/plans/03-cross-platform-transport.md`, and `.sisyphus/plans/04-integration-docs-and-e2e.md` to reflect the canonical topology, the new mandatory matrix, the public-path/protocol-probe split, the runner credential semantics, and the fact that Plan 1 must be rerun under the new process.
  **Must NOT do**: Do not leave Plan 1 marked effectively complete without the rerun requirement. Do not let Plan 4 Task 20b remain count-only or topology-drifting.

  **Recommended Agent Profile**:
  - Category: `writing` - Reason: this is cross-plan coordination and contract alignment.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - documentation/plan alignment rather than test authoring.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 10 | Blocked By: 1, 2, 8

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md` - must stop implying the blocked scenarios are low-risk closeouts.
  - Pattern: `.sisyphus/plans/03-cross-platform-transport.md` - transport plan that must reflect StartTLS/LDAPS and runner semantics.
  - Pattern: `.sisyphus/plans/04-integration-docs-and-e2e.md` - Task 18/19/20b alignment target.
  - Pattern: `.sisyphus/plans/09-ad-e2e-validation-closure.md` - authoritative new process plan.

  **Acceptance Criteria** (agent-executable only):
  - [ ] Active inter-dependent plans all reference the same canonical topology and validation matrix assumptions.
  - [ ] Plan 1 report explicitly states that its current state requires rerun under the Plan 9 process before final certification.
  - [ ] Plan 4 Task 20b explicitly distinguishes public-path matrix rows from protocol probe rows and includes the mandatory runner/credential combinations.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Active plans agree on the new process
    Tool: Bash
    Steps: Grep and read the active plans for topology, runner semantics, and rerun language.
    Expected: No active plan contradicts Plan 9 on topology, matrix requirements, or rerun trigger.
    Evidence: build/activeDirectory/azure-lab/evidence/task-9-plan-alignment.txt

  Scenario: Plan 1 rerun requirement is explicit
    Tool: Bash
    Steps: Inspect the updated Plan 1 report and dependent plans for the rerun gate language.
    Expected: Plan 1 cannot be read as finally certified without the new rerun.
    Evidence: build/activeDirectory/azure-lab/evidence/task-9-plan1-rerun.txt
  ```

  **Commit**: NO | Message: `docs(plan): align dependent ad plans with mandatory e2e closure process` | Files: `.sisyphus/plans/*.md`

- [x] 10. Rerun Plan 1 current-state validation under the new process

  **What to do**: After Tasks 1-9 land, rerun the current Plan 1 state using the new hard-gated process. This rerun must execute preflight first, then the protocol probe matrix, then the mandatory public E2E matrix, and finally compare the outcome against the old Plan 1 report. The rerun must replace the old "could not be validated" table with a definitive status for every row: pass, fail with root cause, or blocked by a newly enforced preflight prerequisite that the process itself now catches before E2E begins.
  **Must NOT do**: Do not inherit the old Plan 1 report conclusions. Do not skip rows because previous evidence existed. Do not treat preflight-caught blockers as equivalent to successful validation.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: this is the final integration and certification rerun.
  - Skills: `[]` - no extra skill required.
  - Omitted: `["maester-test-expert"]` - this is full-system E2E certification, not single-check authoring.

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: Final Verification | Blocked By: 3, 4, 5, 6, 7, 8, 9

  **References** (executor has NO interview context - be exhaustive):
  - Pattern: `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md` - baseline report to supersede.
  - Pattern: `.sisyphus/plans/09-ad-e2e-validation-closure.md` - rerun contract.
  - Pattern: `build/activeDirectory/azure-lab/evidence/` - destination for rerun artifacts.
  - Pattern: `build/activeDirectory/Run-ADTests-And-CopyReports.ps1` - public E2E runner entrypoint or its replacement.
  - Pattern: `build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1` - hard-gate entrypoint.

  **Acceptance Criteria** (agent-executable only):
  - [ ] Preflight, protocol probes, and public E2E matrix all run in the required order for the current Plan 1 state.
  - [ ] Every formerly blocked Plan 1 scenario has a definitive rerun outcome and machine-readable evidence.
  - [ ] The updated Plan 1 report records the rerun date, exact matrix rows executed, and any remaining blockers as process failures rather than narrative caveats.

  **QA Scenarios** (MANDATORY - task incomplete without these):
  ```
  Scenario: Full Plan 1 rerun completes under the new process
    Tool: Bash
    Steps: Execute the hard preflight, protocol probe matrix, and public E2E matrix for the current Plan 1 branch state, then regenerate the report artifacts.
    Expected: Every mandatory row has a recorded outcome and the rerun evidence set is complete.
    Evidence: build/activeDirectory/azure-lab/evidence/task-10-plan1-rerun-summary.json

  Scenario: Old caveats are replaced by definitive rerun status
    Tool: Bash
    Steps: Compare the old and updated Plan 1 report sections for previously blocked scenarios.
    Expected: The old "What Could Not Be Validated" rows are replaced by definitive rerun outcomes or explicit preflight-gate failures.
    Evidence: build/activeDirectory/azure-lab/evidence/task-10-plan1-rerun-diff.txt
  ```

  **Commit**: NO | Message: `test(ad): rerun plan 1 current state under mandatory e2e process` | Files: `build/activeDirectory/azure-lab/evidence/*`, `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md`

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.
- [x] F1. Plan Compliance Audit — oracle
- [x] F2. Code Quality Review — unspecified-high
- [x] F3. Real Manual QA — unspecified-high (+ playwright if UI)
- [x] F4. Scope Fidelity Check — deep

## Commit Strategy
- Work on `ad-multiforest-targeting` only.
- Keep commits split by concern: topology/preflight, protocol/public-path wiring, E2E matrix/evidence, docs/report alignment.
- Do not commit generated evidence until explicitly requested.

## Success Criteria
- All five formerly blocked scenarios execute as mandatory rows in every AD E2E cycle.
- Public-path certification proves the intended protocol-aware AD path is the one exercised.
- Protocol probe certification proves Basic-over-LDAPS and StartTLS success/failure semantics with machine-readable evidence.
- Azure lab preflight blocks execution on any DNS/trust/cert/runner-join drift.
- Plans, docs, scripts, and evidence all describe the same topology and runner contract.

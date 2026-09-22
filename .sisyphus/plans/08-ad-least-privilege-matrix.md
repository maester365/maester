# Plan 8: AD Least-Privilege Capability Matrix

## TL;DR
> **Summary**: Classify every shipped AD test by the minimum capabilities required for meaningful results, document current misleading failure behavior, and publish guidance that distinguishes domain-user-friendly checks from tests that require additional privileged-object reads — without changing collector code or skip logic.
> **Deliverables**: complete AD capability matrix, created or updated `docs/e2e-ad-testing-guide.md`, automated completeness/vocabulary checks, spot-check evidence across representative AD areas.
> **Effort**: Medium
> **Parallel**: YES — 2 waves. **Can execute in parallel with Plans 1–3**; it is classification/documentation only and does not depend on the protocol migration.
> **Critical Path**: Inventory → capability model → matrix publication → automated completeness checks

## Context

### Original Request
Introduce a new plan on `ad-multiforest-targeting` for guidance and assistance on defining the least privilege necessary for each AD test, including which tests can run as a domain user and which require read access over privileged objects.

### Interview Summary
- This plan must stay **discrete** from the SACL/cache fix.
- Scope is **classification and documentation only**; no permission-reduction refactor is included.
- Least-privilege must be expressed in **capability classes**, not role-name labels.
- The published guidance must be honest about current behavior, including places where permission failures are currently hidden as empty results or `NotConnectedActiveDirectory`.

### Metis Review (gaps addressed)
- Separate **RequiredCapability** from **CollectorAttemptedCapability** so broad collectors do not inflate the documented minimum privileges.
- Publish the current state honestly: `LimitedPermissions` / `NotAuthorized` exist as skip categories, but AD tests do not consistently use them today.
- Add machine-verifiable completeness checks so every `powershell/public/ad/Test-MtAd*.ps1` command is represented in the classification artifact.
- Ban role-name language such as `Domain Admin` / `Enterprise Admin` from the source-of-truth matrix.

## Work Objectives

### Core Objective
Produce an evidence-backed least-privilege matrix for all shipped AD tests so operators can understand the minimum capabilities required for meaningful results, the extra capabilities broad collectors may attempt, and the current misleading outcomes to watch for.

### Deliverables
- Source-of-truth capability matrix for all `powershell/public/ad/**/Test-MtAd*.ps1` commands
- Created or updated `docs/e2e-ad-testing-guide.md` explaining capability classes and how to use the matrix
- Automated tests/checks that verify matrix completeness and allowed vocabulary
- Evidence-backed spot checks across DACL, GPO/GPOState, and domain/domaincontroller or DNS areas

### Definition of Done
- Every `powershell/public/ad/**/Test-MtAd*.ps1` command appears in the capability matrix.
- The matrix uses only the approved capability labels:
  - `AD read`
  - `GPO read`
  - `group expansion`
  - `password-policy read`
  - `DNS server read`
  - `DC remoting/admin`
  - `SACL read`
- Every matrix row contains at least: `TestCommand`, `WrapperTest`, `RequiredCapability`, `CollectorAttemptedCapability`, `CurrentFailureSignal`, `CurrentSkipCategory`, `LeastPrivilegeGuidance`, `KnownAmbiguity`.
- `docs/e2e-ad-testing-guide.md` explains how ordinary directory-read scenarios differ from tests that need privileged-object reads, without using role-name language as source-of-truth.
- Machine-verifiable checks pass for completeness and vocabulary.
- `pwsh -NoProfile -File ./powershell/tests/pester.ps1` passes.

### Must Have
- Classification/documentation only
- Capability-based vocabulary
- Honest “current behavior” notes for misleading empty/partial results
- Automated completeness/vocabulary verification

### Must NOT Have
- No collector refactor
- No skip-logic standardization
- No privilege-reduction implementation work
- No generated-doc hand edits under `website/docs/**` or versioned docs
- No role-name source-of-truth language in the matrix

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: tests-after plus automated documentation consistency checks
- QA policy: each task includes happy-path and failure/edge-path checks
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy

### Parallel Execution Waves
Wave 1: inventory + capability model + matrix draft
Wave 2: docs publication + automated completeness/vocabulary checks

### Dependency Matrix
| Task | Blocks | Blocked By |
|------|--------|------------|
| 1 | 2, 3, 4 | — |
| 2 | 3, 4 | 1 |
| 3 | 4 | 1, 2 |
| 4 | F1–F4 | 1, 2, 3 |

### Agent Dispatch Summary
- Wave 1: 2 tasks — deep + writing
- Wave 2: 2 tasks — writing + unspecified-high
- Final Verification: 4 parallel review agents

## TODOs

- [ ] 1. Inventory All AD Test Commands and Actual Dependency Paths

  **What to do**:
  - Inventory every `powershell/public/ad/**/Test-MtAd*.ps1` command.
  - For each command, map:
    - corresponding wrapper test under `tests/ad/**` when present
    - collector(s) used (`Get-MtADDomainState`, `Get-MtADGpoState`, `Get-MtADDacls`, etc.)
    - any direct follow-on cmdlets (for example group expansion, password-policy reads, DNS reads, remoting)
    - current failure symptom (`$null`, empty set, misleading pass/fail, `NotConnectedActiveDirectory`, etc.)
  - Store the raw inventory as a machine-readable artifact used by later tasks.

  **Must NOT do**: Do not classify by human role names. Do not edit docs in this task.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: broad code-path inventory across all AD test commands
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 2, 3, 4 | Blocked By: —

  **References**:
  - Pattern: `powershell/public/ad/**/*.ps1` - source-of-truth AD test commands
  - Pattern: `tests/ad/**/*.Tests.ps1` - shipped wrapper tests
  - Pattern: `powershell/public/Get-MtADDomainState.ps1:128-176,379-466` - mixed collector capabilities and DACL path
  - Pattern: `powershell/public/Get-MtADGpoState.ps1:52-119` - GPO/GPOState collection and partial-failure behavior
  - Pattern: `powershell/public/Get-MtADDacls.ps1` - explicit SACL-read path

  **Acceptance Criteria**:
  - [ ] A machine-readable inventory exists covering every `powershell/public/ad/**/Test-MtAd*.ps1` command.
  - [ ] Every inventory row includes command path, wrapper path when present, collector dependencies, and current failure signal.
  - [ ] At least one example from DACL, GPO/GPOState, and domain/domaincontroller or DNS is annotated with direct follow-on cmdlets.

  **QA Scenarios**:
  ```
  Scenario: Inventory completeness baseline
    Tool: Bash
    Steps: Count `powershell/public/ad/**/Test-MtAd*.ps1` files and compare against the generated inventory row count.
    Expected: Counts match exactly.
    Evidence: .sisyphus/evidence/task-1-inventory-counts.txt

  Scenario: Representative dependency-path check
    Tool: Bash
    Steps: Spot-check one DACL command, one GPO/GPOState command, and one domain/domaincontroller or DNS command against the inventory.
    Expected: Each row matches the actual code path and notes the current failure signal.
    Evidence: .sisyphus/evidence/task-1-spot-checks.txt
  ```

  **Commit**: NO | Message: `docs(ad): inventory AD test capability dependencies` | Files: `docs/**`, `.sisyphus/evidence/**`

- [ ] 2. Build the Capability Matrix with Honest Current-State Semantics

  **What to do**:
  - Create the source-of-truth matrix as a committed artifact under `docs/` using a machine-verifiable format (`.csv` or `.json`); prefer `docs/ad-least-privilege-matrix.csv` unless a JSON format is already established by adjacent docs tooling.
  - Use only the approved capability vocabulary:
    - `AD read`
    - `GPO read`
    - `group expansion`
    - `password-policy read`
    - `DNS server read`
    - `DC remoting/admin`
    - `SACL read`
  - For each AD test command, populate:
    - `TestCommand`
    - `WrapperTest`
    - `RequiredCapability`
    - `CollectorAttemptedCapability`
    - `CurrentFailureSignal`
    - `CurrentSkipCategory`
    - `LeastPrivilegeGuidance`
    - `KnownAmbiguity`
  - Mark DACL tests as DACL-read-backed via `Get-MtADDomainState`, not as SACL-read tests, unless a specific command directly calls `Get-MtADDacls`.
  - Explicitly document current misleading cases where empty/partial datasets can masquerade as valid results.

  **Must NOT do**: Do not present recommended future skip behavior as if it were current behavior. Do not use role labels like `Domain Admin` or `Enterprise Admin`.

  **Recommended Agent Profile**:
  - Category: `writing` - Reason: structured, evidence-backed documentation artifact
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 3, 4 | Blocked By: 1

  **References**:
  - Pattern: `powershell/public/Add-MtTestResultDetail.ps1:75-82` - available skip categories
  - Pattern: `powershell/internal/Get-MtSkippedReason.ps1:20,35,38` - `NotConnectedActiveDirectory`, `LimitedPermissions`, `NotAuthorized`
  - Pattern: `powershell/public/ad/dacl/Test-MtAdDaclPrivilegedAllowAceDetails.ps1` - empty-data can look like no findings
  - Pattern: `powershell/public/ad/gpostate/Test-MtAdGpoNoPermissionsCount.ps1` - partial/empty GPO permission semantics

  **Acceptance Criteria**:
  - [ ] The committed matrix contains a row for every AD test command.
  - [ ] The matrix uses only approved capability labels.
  - [ ] The matrix contains no banned role-name language.
  - [ ] DACL, GPO/GPOState, and one domain/domaincontroller or DNS section each include explicit `KnownAmbiguity` notes where current behavior can mislead users.

  **QA Scenarios**:
  ```
  Scenario: Allowed-vocabulary validation
    Tool: Bash
    Steps: Run a validation script/test that checks every matrix row against the approved capability labels.
    Expected: All rows pass; no unapproved labels appear.
    Evidence: .sisyphus/evidence/task-2-vocabulary-check.txt

  Scenario: No role-name language
    Tool: Bash
    Steps: Search the matrix for banned role-name strings such as `Domain Admin`, `Enterprise Admin`, and similar role labels.
    Expected: Zero banned role-name matches.
    Evidence: .sisyphus/evidence/task-2-role-language-check.txt
  ```

  **Commit**: YES | Message: `docs(ad): add least-privilege capability matrix` | Files: `docs/ad-least-privilege-matrix.*`

- [ ] 3. Update the AD E2E Guide to Explain How to Use the Matrix

  **What to do**:
  - Create `docs/e2e-ad-testing-guide.md` if it does not already exist on the branch; otherwise update it in place as the operator-facing narrative entry point.
  - Add sections for:
    - capability-model overview
    - how to distinguish ordinary directory-read scenarios from privileged-object read scenarios
    - how to use the matrix before running tests in constrained environments
    - current known misleading outcomes (`NotConnectedActiveDirectory`, empty DACL/GPO findings, partial data)
    - clear statement that the matrix documents **current behavior**, not a future enforcement model
    - Plan 9 E2E validation overview: canonical lab topology (`MiSouleDC02/misoule02.local`, `MiSouleDC03/child.misoule02.local`, `MiSouleDC04/misoule03.local`, `MiSouleRunnerWin`, `MiSouleRunnerLinux`), the three-track mandatory validation process (hard preflight gate, protocol probe matrix, public E2E runner matrix), and how the capability matrix maps to mandatory E2E rows
  - When mentioning domain-user-friendly scenarios, phrase them as capability guidance (for example, “tests requiring only `AD read` often succeed with ordinary directory read access commonly available to domain users”), not as role requirements.
  - Keep generated docs untouched.

  **Must NOT do**: Do not edit generated docs in `website/docs/**` or versioned docs. Do not promise that current tests reliably emit `LimitedPermissions` or `NotAuthorized`.

  **Recommended Agent Profile**:
  - Category: `writing` - Reason: operator-facing guidance update
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: 4 | Blocked By: 1, 2

  **References**:
  - Pattern: `docs/e2e-ad-testing-guide.md` - operator-facing AD guidance document to create or extend in this task
  - Pattern: `docs/ad-least-privilege-matrix.*` - new source-of-truth matrix from Task 2
  - Pattern: `powershell/public/ad/domain/Test-MtAdForestDomainCount.ps1` - example of current `NotConnectedActiveDirectory` fallback

  **Acceptance Criteria**:
  - [ ] `docs/e2e-ad-testing-guide.md` contains the capability-model overview and matrix-usage instructions.
  - [ ] The guide clearly distinguishes current observed behavior from recommended future enforcement.
  - [ ] The guide does not use banned role-name language as source-of-truth.

  **QA Scenarios**:
  ```
  Scenario: Guide references the matrix and capability model
    Tool: Bash
    Steps: Search `docs/e2e-ad-testing-guide.md` for the matrix artifact path and all approved capability classes.
    Expected: The guide references the matrix and the capability vocabulary explicitly.
    Evidence: .sisyphus/evidence/task-3-guide-capability-check.txt

  Scenario: Current-vs-future wording check
    Tool: Bash
    Steps: Search the guide for required phrases indicating `current behavior` and `known ambiguity` and verify there is no text that claims future skip-logic behavior as already implemented.
    Expected: The guide preserves current-state honesty.
    Evidence: .sisyphus/evidence/task-3-current-state-check.txt
  ```

  **Commit**: YES | Message: `docs(ad): document least-privilege usage guidance` | Files: `docs/e2e-ad-testing-guide.md`

- [ ] 4. Add Automated Completeness and Consistency Verification

  **What to do**:
  - Add automated tests or validation scripts under `powershell/tests/` or a repo-appropriate verification location to ensure:
    - every `powershell/public/ad/**/Test-MtAd*.ps1` command appears in the matrix
    - only approved capability labels appear
    - banned role-name language does not appear in the matrix or guide
  - Add evidence-backed spot checks for at least:
    - one DACL test
    - one GPO/GPOState test
    - one domain/domaincontroller or DNS test
  - Run `pwsh -NoProfile -File ./powershell/tests/pester.ps1`.

  **Must NOT do**: Do not rely on manual review as acceptance evidence.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: docs verification automation plus test execution
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: F1–F4 | Blocked By: 1, 2, 3

  **References**:
  - Pattern: `pwsh -NoProfile -File ./powershell/tests/pester.ps1` - required repo-safe verification
  - Pattern: `docs/ad-least-privilege-matrix.*` - committed matrix artifact
  - Pattern: `docs/e2e-ad-testing-guide.md` - committed narrative guide

  **Acceptance Criteria**:
  - [ ] Automated completeness check proves every AD test command is represented in the matrix.
  - [ ] Automated vocabulary check proves only approved capability labels are used.
  - [ ] Automated banned-language check proves no role-name source-of-truth language appears.
  - [ ] `pwsh -NoProfile -File ./powershell/tests/pester.ps1` passes.

  **QA Scenarios**:
  ```
  Scenario: Matrix completeness verification
    Tool: Bash
    Steps: Run the automated check that compares `powershell/public/ad/**/Test-MtAd*.ps1` inventory against matrix rows.
    Expected: Zero missing or extra command rows.
    Evidence: .sisyphus/evidence/task-4-matrix-completeness.txt

  Scenario: Evidence-backed representative spot checks
    Tool: Bash
    Steps: Run the automated spot-check validation for one DACL, one GPO/GPOState, and one domain/domaincontroller or DNS command.
    Expected: The documented capability rows match the actual code paths and include current ambiguity notes where required.
    Evidence: .sisyphus/evidence/task-4-representative-spot-checks.txt
  ```

  **Commit**: YES | Message: `test(ad): verify least-privilege matrix completeness` | Files: `powershell/tests/**`, `docs/**`, `.sisyphus/evidence/**`

## Final Verification Wave
- [ ] F1. Plan Compliance Audit — oracle
  Verify with exact checks: no collector refactor entered this plan; matrix is capability-based; current-state vs future-state wording is explicit; generated docs were not hand-edited.
- [ ] F2. Code Quality Review — unspecified-high
  Verify with exact checks: completeness/vocabulary tests are automated; banned role-name language is absent; representative ambiguity notes are present.
- [ ] F3. Real QA Execution — unspecified-high
  Verify with exact checks: run `pwsh -NoProfile -File ./powershell/tests/pester.ps1`; run the matrix completeness/vocabulary checks; capture logs.
- [ ] F4. Scope Fidelity Check — deep
  Verify with exact checks: no skip-logic changes, no permission-reduction refactor, no generated-doc edits, and no unsupported privilege claims.

## Commit Strategy
- `docs(ad): add least-privilege capability matrix`
- `docs(ad): document least-privilege usage guidance`
- `test(ad): verify least-privilege matrix completeness`

## Success Criteria
- Every shipped AD test command has a documented least-privilege row.
- The matrix is machine-verifiably complete and vocabulary-compliant.
- `docs/e2e-ad-testing-guide.md` explains how to use the matrix without overstating current behavior.
- Representative DACL, GPO/GPOState, and domain/domaincontroller or DNS examples are evidence-backed.
- Final verification wave passes and is approved.
- Plan 9 E2E alignment: `docs/e2e-ad-testing-guide.md` references the canonical lab topology and three-track mandatory validation process; the capability matrix supports the mandatory public E2E runner matrix and protocol probe matrix rows defined in Plan 9.

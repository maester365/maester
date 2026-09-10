# Plan 7: AD SACL Cache Stability

## TL;DR
> **Summary**: Stabilize the narrow SACL/ACL collector path in `Get-MtADDacls` so large-object environments stop freezing PowerShell sessions, without widening scope into the broader AD collector architecture.
> **Deliverables**: preserved-function contract baseline, memory-safe `Get-MtADDacls` implementation, scoped cache-key fix for `-DnBase`, AD-capable regression/perf evidence.
> **Effort**: Short
> **Parallel**: YES — 2 waves. **Can execute in parallel with Plans 1–3**; it is scoped to `Get-MtADDacls` only and does not depend on the protocol migration.
> **Critical Path**: Contract baseline → collector stabilization → cache-scope fix → perf/correctness verification

## Context

### Original Request
Introduce a new plan on `ad-multiforest-targeting` to address a bug around SACL caching where environments with thousands of objects cause the PowerShell session to freeze, likely due to memory limitations.

### Interview Summary
- This plan must stay **discrete** from the least-privilege work.
- Scope is a **narrow fix for now**, not a broader AD collector redesign.
- The most relevant hot path is `powershell/public/Get-MtADDacls.ps1`, which is the only explicit `SecurityMasks::Sacl` path in the repo.
- `Get-MtADDomainState.ps1` is intentionally **out of scope** for this plan except as an escalation trigger if freezes persist after the narrow fix.

### Metis Review (gaps addressed)
- Preserve the public contract of `Get-MtADDacls` up front: same return shape, same disconnected behavior, same `-Refresh` semantics, same default `DnBase` behavior.
- Treat the root cause as **memory / materialization pressure**, not as “SACL alone did it”: `FindAll()`, repeated ADSI rebinding, `$dacls +=`, undisposed search results, and unbounded session caching are all in scope.
- Keep known broader issues explicit but deferred: generalized AD cache redesign, `Get-MtADDomainState` memory pressure, and permission-signaling inconsistencies in other collectors.

## Work Objectives

### Core Objective
Make `Get-MtADDacls` complete reliably and promptly in large environments by reducing unnecessary security-descriptor overfetch, eliminating obvious memory-growth patterns, and preventing cache poisoning across repeated `-DnBase` calls.

### Deliverables
- Contract baseline and repro harness for `Get-MtADDacls`
- Memory-safe collector implementation in `powershell/public/Get-MtADDacls.ps1`
- Targeted module tests under `powershell/tests/`
- AD-capable repro log with explicit timeout budget

### Definition of Done
- `Get-MtADDacls` still returns `$null` when AD is not connected.
- `-Refresh` still forces recollection and non-`-Refresh` still reuses cache for the same scope.
- Repeated calls with different `-DnBase` values do not reuse the wrong cached result.
- The collector no longer requests SACL data unless a future explicit opt-in path is introduced.
- Search results and searcher objects are explicitly disposed.
- Array-growth hot spots (`+=`) are removed from the collector path.
- `pwsh -NoProfile -File ./powershell/tests/pester.ps1` passes.
- AD-capable repro evidence shows prompt completion under a fixed timeout budget and no indefinite hang on access failure.

### Must Have
- Narrow scope limited to `Get-MtADDacls`
- No return-shape break for current callers
- Explicit timeout-based repro evidence
- Cache behavior documented for same-scope and different-`DnBase` calls

### Must NOT Have
- No refactor of `Get-MtADDomainState.ps1`
- No generalized AD cache TTL/eviction redesign
- No privilege-classification work (belongs to Plan 8)
- No silent changes to output ordering/shape unless covered by regression tests
- No hand-wavy acceptance criteria like “no freeze observed”

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: tests-after for the contract baseline, then targeted regression/perf verification
- QA policy: each task includes happy-path and failure/edge-path checks
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy

### Parallel Execution Waves
Wave 1: contract baseline + collector stabilization
Wave 2: cache-scope fix + AD-capable regression/perf verification

### Dependency Matrix
| Task | Blocks | Blocked By |
|------|--------|------------|
| 1 | 2, 3, 4 | — |
| 2 | 3, 4 | 1 |
| 3 | 4 | 1, 2 |
| 4 | F1–F4 | 1, 2, 3 |

### Agent Dispatch Summary
- Wave 1: 2 tasks — unspecified-high
- Wave 2: 2 tasks — unspecified-high
- Final Verification: 4 parallel review agents

## TODOs

- [ ] 1. Freeze `Get-MtADDacls` Contract and Build Repro Harness

  **What to do**:
  - Read `powershell/public/Get-MtADDacls.ps1` and freeze the current public contract in tests:
    - returns `$null` when AD is not connected
    - supports `-Refresh`
    - default `DnBase` behavior remains unchanged
    - returned item shape remains unchanged for representative ACE fields
  - Add module tests under `powershell/tests/` that cover disconnected behavior, first-call collection, second-call cache reuse, and repeated calls with different `DnBase` values.
  - Add an AD-capable repro command/script under `build/activeDirectory/` or `powershell/tests/` that invokes `Get-MtADDacls` with a timeout and emits timing/evidence logs.
  - Capture baseline evidence before changing the collector.

  **Must NOT do**: Do not change collector behavior in this task. Do not broaden into `Get-MtADDomainState`.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: function-contract mapping plus test harness creation
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 2, 3, 4 | Blocked By: —

  **References**:
  - Pattern: `powershell/public/Get-MtADDacls.ps1:47-82` - cache key, SACL mask, `FindAll()`, `$dacls +=`, cache write
  - Pattern: `powershell/public/Clear-MtADCache.ps1` - current cache reset behavior
  - Pattern: `powershell/internal/Clear-ModuleVariable.ps1` - per-run cache clear
  - Pattern: `powershell/tests/functions/ActiveDirectoryOptIn.Tests.ps1` - AD opt-in/guard expectations

  **Acceptance Criteria**:
  - [ ] A targeted Pester file under `powershell/tests/` asserts disconnected `$null`, first-call collection, second-call cache reuse, and different-`DnBase` isolation.
  - [ ] A repro command/script exists with an explicit timeout budget of `300s` and writes timing/output logs.
  - [ ] Baseline evidence is captured before collector changes.

  **QA Scenarios**:
  ```
  Scenario: Disconnected contract baseline
    Tool: Bash
    Steps: Run `pwsh -NoProfile -Command "Import-Module ./powershell/Maester.psd1 -Force; Disconnect-Maester -ErrorAction SilentlyContinue; $r = Get-MtADDacls; if ($null -ne $r) { throw 'Expected null when disconnected' }"`
    Expected: Command exits 0 and returns promptly.
    Evidence: .sisyphus/evidence/task-1-disconnected-contract.txt

  Scenario: Repro harness timeout baseline
    Tool: Bash
    Steps: Run the new AD-capable repro command with `timeout 300s` and capture stdout/stderr.
    Expected: Output log and elapsed-time log are written even if the current implementation is slow or fails.
    Evidence: .sisyphus/evidence/task-1-repro-baseline.txt
  ```

  **Commit**: NO | Message: `test(ad): freeze Get-MtADDacls contract and repro harness` | Files: `powershell/tests/**`, `build/activeDirectory/**`

- [ ] 2. Stabilize `Get-MtADDacls` Memory and Descriptor Collection Path

  **What to do**:
  - Limit this task strictly to `powershell/public/Get-MtADDacls.ps1`.
  - Remove default `SecurityMasks::Sacl` overfetch because the function only exposes access rules, not audit rules.
  - Stop rebinding each object through ADSI just to read `.ObjectSecurity.Access`; instead parse the already-loaded `ntsecuritydescriptor` binary directly into `ActiveDirectorySecurity` and enumerate access rules from that object.
  - Replace repeated `$dacls +=` growth with a typed list or equivalent append pattern.
  - Explicitly dispose both the `DirectorySearcher` and the `SearchResultCollection` returned by `FindAll()`.
  - Preserve output shape and representative field values for current callers.

  **Must NOT do**: Do not add new public parameters. Do not introduce a generalized cache redesign. Do not change ordering/shape without regression coverage.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: narrow function change with correctness constraints
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 3, 4 | Blocked By: 1

  **References**:
  - Pattern: `powershell/public/Get-MtADDacls.ps1:65-81` - current materialization path to replace
  - Pattern: `powershell/public/Get-MtADDomainState.ps1:379-466` - direct `ntsecuritydescriptor` parsing precedent
  - Pattern: `build/activeDirectory/Get-AdDacls.ps1` - older descriptor-collection script for behavior comparison

  **Acceptance Criteria**:
  - [ ] `Get-MtADDacls.ps1` no longer requests `SecurityMasks::Sacl` by default.
  - [ ] No `+=` growth remains in the hot collection loop.
  - [ ] `SearchResultCollection` is explicitly disposed.
  - [ ] Contract tests from Task 1 still pass.

  **QA Scenarios**:
  ```
  Scenario: Correctness parity on representative ACE fields
    Tool: Bash
    Steps: Run the targeted Pester tests that compare object count, ACE count, and representative ACE fields before/after on a controlled dataset.
    Expected: Counts and representative fields match the frozen contract.
    Evidence: .sisyphus/evidence/task-2-correctness-parity.txt

  Scenario: Failure path returns promptly on access denial
    Tool: Bash
    Steps: Run the AD-capable repro command against a scope that denies descriptor access using `timeout 300s`.
    Expected: Command exits or fails within the timeout budget and writes a bounded error log instead of hanging indefinitely.
    Evidence: .sisyphus/evidence/task-2-access-denied-timeout.txt
  ```

  **Commit**: YES | Message: `fix(ad): stabilize Get-MtADDacls memory path` | Files: `powershell/public/Get-MtADDacls.ps1`, `powershell/tests/**`

- [ ] 3. Fix Cache Scope for Repeated `-DnBase` Calls Without Widening Scope

  **What to do**:
  - Replace the single `'Dacls'` cache key with a normalized cache key that includes `DnBase` when `-DnBase` is supplied.
  - Preserve current behavior for the default no-`DnBase` path.
  - Preserve `-Refresh` semantics for each normalized scope.
  - Document this as a bug fix for scoped cache poisoning, not as a generalized multi-target cache redesign.
  - Add tests that prove one `DnBase` call cannot poison a later call for a different base.

  **Must NOT do**: Do not redesign all AD cache keys. Do not add TTL or eviction policies in this plan.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: targeted cache semantics change with regression risk
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: 4 | Blocked By: 1, 2

  **References**:
  - Pattern: `powershell/public/Get-MtADDacls.ps1:47-49` - current single-key cache behavior
  - Pattern: `powershell/public/Get-MtADDomainState.ps1:53` - parameterized cache-key precedent

  **Acceptance Criteria**:
  - [ ] Repeated calls with different `-DnBase` values produce scope-correct results.
  - [ ] Same-scope repeated non-`-Refresh` calls reuse cache.
  - [ ] Same-scope `-Refresh` recollects data.

  **QA Scenarios**:
  ```
  Scenario: Same-scope cache reuse
    Tool: Bash
    Steps: Run targeted Pester tests that call `Get-MtADDacls` twice with the same `DnBase` and no `-Refresh`.
    Expected: The second call reuses the cached scope and does not recollect.
    Evidence: .sisyphus/evidence/task-3-same-scope-cache.txt

  Scenario: Different-scope isolation
    Tool: Bash
    Steps: Run targeted Pester tests that call `Get-MtADDacls -DnBase A`, then `Get-MtADDacls -DnBase B`, then re-check both scopes.
    Expected: Results remain isolated per base and no scope is poisoned by the other.
    Evidence: .sisyphus/evidence/task-3-dnbase-isolation.txt
  ```

  **Commit**: YES | Message: `fix(ad): scope Get-MtADDacls cache by dnbase` | Files: `powershell/public/Get-MtADDacls.ps1`, `powershell/tests/**`

- [ ] 4. Produce AD-Capable Regression and Performance Evidence

  **What to do**:
  - Run the targeted module tests and the full module test suite.
  - Run the AD-capable repro command twice for the same scope (first collect, then cached repeat).
  - Record elapsed time, peak/logged behavior, object count, and ACE count.
  - Record the access-denied / disconnected failure-path behavior.
  - Store all evidence under `.sisyphus/evidence/`.
  - Document escalation triggers for a follow-on `Get-MtADDomainState` plan if freezes persist in shipped AD test paths.

  **Must NOT do**: Do not claim success for shipped DACL tests or `Invoke-Maester` globally unless evidence shows they use `Get-MtADDacls` and benefit directly.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: test execution plus evidence synthesis
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: F1–F4 | Blocked By: 1, 2, 3

  **References**:
  - Pattern: `pwsh -NoProfile -File ./powershell/tests/pester.ps1` - required repo-safe verification
  - Pattern: `build/activeDirectory/Run-ADTests-And-CopyReports.ps1` - AD runner context
  - Pattern: `powershell/public/core/Test-MtConnection.ps1` - AD connection gating

  **Acceptance Criteria**:
  - [ ] `pwsh -NoProfile -File ./powershell/tests/pester.ps1` passes.
  - [ ] Repro evidence shows first-call collection and second-call cached repeat complete within `300s` each.
  - [ ] Access-denied and disconnected scenarios return promptly with bounded logs.
  - [ ] Escalation criteria are documented if freezes persist outside `Get-MtADDacls`.

  **QA Scenarios**:
  ```
  Scenario: Happy path cached repeat
    Tool: Bash
    Steps: Run the AD-capable repro command twice for the same scope with `timeout 300s` and capture elapsed times.
    Expected: Both runs complete within budget; the second run is cache-backed and does not recollect.
    Evidence: .sisyphus/evidence/task-4-cached-repeat.txt

  Scenario: Missing module / disconnected failure path
    Tool: Bash
    Steps: Run a targeted Pester case that simulates AD disconnected or missing AD module.
    Expected: The function returns `$null` or the documented bounded failure signal promptly; no hang occurs.
    Evidence: .sisyphus/evidence/task-4-failure-path.txt
  ```

  **Commit**: YES | Message: `test(ad): verify Get-MtADDacls stability and timeout behavior` | Files: `powershell/tests/**`, `build/activeDirectory/**`, `.sisyphus/evidence/**`

## Final Verification Wave
- [ ] F1. Plan Compliance Audit — oracle
  Verify with exact checks: scope stayed limited to `Get-MtADDacls`; no `Get-MtADDomainState` refactor slipped in; preserved contracts are still true; deferred items remain explicitly deferred.
- [ ] F2. Code Quality Review — unspecified-high
  Verify with exact checks: no `+=` remains in the hot collector loop; disposals are explicit; tests cover disconnected/cache/isolation behavior.
- [ ] F3. Real QA Execution — unspecified-high
  Verify with exact checks: run `pwsh -NoProfile -File ./powershell/tests/pester.ps1`; run the AD-capable repro command with `timeout 300s`; capture logs and timings.
- [ ] F4. Scope Fidelity Check — deep
  Verify with exact checks: no privilege-classification work entered this plan; no generalized AD cache redesign entered this plan; only `Get-MtADDacls` and its direct tests/harness changed.

## Commit Strategy
- `fix(ad): stabilize Get-MtADDacls memory path`
- `fix(ad): scope Get-MtADDacls cache by dnbase`
- `test(ad): verify Get-MtADDacls stability and timeout behavior`

## Success Criteria
- `Get-MtADDacls` remains contract-compatible and completes within the stated timeout budget.
- Scoped cache poisoning across different `DnBase` values is eliminated.
- Explicit SACL overfetch is removed from the default path.
- Evidence exists for happy-path, disconnected, and access-denied behavior.
- Final verification wave passes and is approved.

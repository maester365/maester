# Plan 6: AD Test Operational Value & Good Practice Guidance

> **Reference View** — This plan improves Maester's existing Active Directory test suite to provide operational value and good-practice guidance on why each test matters. It enriches the canonical guidance layer (`powershell/public/ad/**`), keeps test wrappers thin, and adds net-new security assertion tests where justified.

## TL;DR
> **Summary**: Inventory all ~270 AD files, classify each check by semantics and severity, define a standard guidance template contract, enrich existing public AD functions with tiered operational guidance (lightweight or rich markdown), and add net-new security assertion tests for known weaknesses with industry-accepted thresholds — all while preserving backward compatibility for existing tests.
> **Deliverables**: Complete AD check classification matrix, guidance template contract, enriched public AD functions with adjacent `.md` templates, net-new security assertion tests, deprecation list, updated documentation.
> **Effort**: XL
> **Parallel**: YES — 6 waves
> **Critical Path**: Inventory → Template Contract → Stable Category Guidance → Stable Category Assertions → Dependent Category Guidance → Dependent Category Assertions → Docs & Validation

## Context

### Original Request
Add a sixth plan for improving the current AD tests to ensure they provide operational value and good practice guidance on why the tests matter.

### Interview Summary
- **Scope**: All ~270 AD `.ps1` files across 19 categories under `tests/ad/` and `powershell/public/ad/`.
- **Test evolution**: Hybrid — existing tests keep current pass/fail behavior (guidance-only enrichment). New security assertion tests are net-add. A deprecation list tracks operational tests that overlap significantly with new security tests.
- **Guidance layer**: Canonical guidance lives in `powershell/public/ad/**` public functions (current AD architecture), enriched via `Add-MtTestResultDetail` and adjacent `.md` templates. `tests/ad/**` wrappers remain thin.
- **Guidance depth**: Tiered — rich markdown (benefits, remediation steps, impacted resources, related links) for highest-severity tests; lightweight standard template (Why It Matters, Risk, Remediation, References) for lower-severity/inventory tests.
- **Assertion rubric**: Moderate — a check becomes a failing assertion if it represents a known security weakness with an industry-accepted best-practice threshold.
- **Backward compatibility**: Existing test pass/fail semantics are preserved. Breaking changes are not introduced to existing test IDs.

### Metis Review (gaps addressed)
- **Scope underestimation corrected**: ~270 files, not ~150. Plan includes an executable inventory step.
- **Canonical layer resolved**: Public functions own guidance; wrappers stay thin. Avoids duplication with Entra pattern.
- **Dependency gating**: Waves 4–5 are gated on Plan 2 (LDAP collectors) and Plan 3 (cross-platform transport) stability. Plan 5 overlap is managed via classification matrix.
- **Assertion rubric**: Explicit moderate criteria defined in Task 2.
- **Severity source**: Derived from mapping to CIS/Microsoft baselines and internal risk assessment; not invented ad-hoc.
- **Report bloat guard**: Rich markdown capped per check; summary-vs-detail strategy defined in template contract.

## Work Objectives

### Core Objective
Transform Maester's AD test suite from a collection of data-retrieval checks into an operationally valuable security assessment tool that explains why each finding matters, what risk it poses, and what remediation steps to take.

### Deliverables
1. **AD Check Classification Matrix** (CSV/JSON): Every AD check mapped to wrapper path, public function path, category, current semantics, target semantics, guidance depth, severity, references, and Plan 2/3/5 dependencies.
2. **Guidance Template Contract**: Standard lightweight template + rich markdown template specifications.
3. **Enriched Public AD Functions**: All stable-category public functions updated with operational guidance via `Add-MtTestResultDetail` and adjacent `.md` templates.
4. **Net-New Security Assertion Tests**: New failing tests for known AD security weaknesses with industry-accepted thresholds.
5. **Deprecation List**: Operational tests marked for future deprecation where new security tests provide overlapping coverage.
6. **Updated Documentation**: Regenerated command docs and any new operational guidance pages.

### Definition of Done (verifiable conditions with commands)
- [ ] `./powershell/tests/pester.ps1` passes with zero failures.
- [ ] `./build/Build-MaesterModule.ps1` succeeds.
- [ ] `./build/Test-MaesterModuleOutput.ps1` validates.
- [ ] Every AD check in the classification matrix has a defined guidance depth and severity.
- [ ] Every enriched public function in **stable categories** emits the expected guidance sections at runtime (verified by structural QA).
- [ ] New security assertion tests in **stable categories** have Pester fixtures with pass/fail/boundary cases.
- [ ] Report renders both lightweight and rich markdown correctly in HTML output.
- [ ] No existing test ID has changed pass/fail semantics.
- [ ] Dependent-category work is either completed (if Plan 2/3 gate passes) or documented as deferred with a follow-on plan reference.
- [ ] Any E2E validation of new or enriched checks follows the Plan 9 three-track mandatory process against the canonical lab topology (`MiSouleDC02/misoule02.local`, `MiSouleDC03/child.misoule02.local`, `MiSouleDC04/misoule03.local`, `MiSouleRunnerWin`, `MiSouleRunnerLinux`).

### Must Have
- Complete inventory and classification of all AD checks.
- Written assertion rubric applied consistently.
- Guidance enrichment for all **stable-category** public functions.
- At least 10 net-new security assertion tests covering high-impact AD weaknesses in **stable categories**.
- Deprecation list with justification for each entry.
- Agent-executed QA for every wave.
- **Conditional**: If Plan 2/3 stability gate passes, guidance enrichment and net-new assertions for dependent categories.

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- No changes to AD protocol, transport, or collector layer (Plans 1–3 own this).
- No changes to test wrapper pass/fail logic for existing tests.
- No new check families outside AD scope.
- No broad renaming or ID churn for existing tests.
- No silent invention of a severity system without documented source.
- No duplication of guidance between public functions and test wrappers.
- No conversion of advisory/inventory checks into failing assertions without rubric justification.
- No manual-only verification steps.

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- **Test decision**: Tests-after for guidance enrichment; TDD for net-new security assertion tests.
- **QA policy**: Every task has agent-executed scenarios (happy path + failure/edge path).
- **Evidence**: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy

### Parallel Execution Waves
> Target: 5-8 tasks per wave. <3 per wave (except final) = under-splitting.

**Wave 1: Foundation** — Inventory, classification, template contract, assertion rubric.
**Wave 2: Stable Category Guidance** — Enrich public functions for categories not affected by Plans 2/3/5.
**Wave 3: Stable Category Assertions** — Add net-new security tests for stable categories.
**Wave 4: Dependent Category Guidance** — Enrich public functions for Plan 2/3-dependent categories (after upstream plans settle).
**Wave 5: Dependent Category Assertions** — Add net-new security tests for dependent categories.
**Wave 6: Documentation, Deprecation & Final Validation** — Docs regeneration, deprecation list finalization, verification waves.

### Dependency Matrix (full, all tasks)
| Task | Blocks | Blocked By |
|------|--------|------------|
| 1 (Inventory) | 2, 3, 4, 5, 6, 7, 8 | — |
| 2 (Rubric + Template) | 3, 4, 5, 6, 7, 8 | 1 |
| 3 (Stable Guidance) | — | 1, 2 |
| 4 (Stable Assertions) | — | 1, 2, 3 |
| 5 (Plan 2/3 Dependency Gate) | 6, 7 | Plan 2, Plan 3 completion |
| 6 (Dependent Guidance) | — | 1, 2, 5 |
| 7 (Dependent Assertions) | — | 1, 2, 5, 6 |
| 8 (Docs + Validation) | F1–F4 | 3, 4, 6, 7 |

### Agent Dispatch Summary (wave → task count → categories)
- Wave 1: 2 tasks — deep research + quick
- Wave 2: 2 tasks — unspecified-high
- Wave 3: 2 tasks — unspecified-high
- Wave 4: 1 task — deep
- Wave 5: 2 tasks — unspecified-high
- Wave 6: 3 tasks — writing + unspecified-high + deep
- Final Verification: 4 parallel review agents

## TODOs

- [ ] 1. Generate Complete AD Check Inventory & Classification Matrix

  **What to do**:
  - Enumerate every `.ps1` file under `tests/ad/` and `powershell/public/ad/`.
  - Map each test wrapper to its corresponding public function.
  - Record: TestId, wrapper path, public function path, category, current semantics (retrieval/assertion), target semantics (operational/assertion/deferred), guidance depth (rich/standard/none), severity source, authoritative references, dependency on Plans 2/3/5.
  - Store as machine-readable CSV/JSON under `.sisyphus/evidence/`.
  - Use `ast_grep_search` to identify thin wrappers (tests that only call a public function and assert retrievability).
  - Use `grep` to count public functions assigning `$testResult = $true`.

  **Must NOT do**: Do not modify any files during inventory. Do not assume 1:1 wrapper:function mapping without verification.

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: requires systematic codebase traversal and cross-referencing
  - Skills: `[]`
  - Omitted: `[]`

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 2, 3, 4, 5, 6, 7, 8 | Blocked By: —

  **References**:
  - Pattern: `tests/ad/**` — all AD test wrappers
  - Pattern: `powershell/public/ad/**` — all public AD functions
  - Tool: `ast_grep_search` with pattern `It $NAME { $RESULT | Should -Be $true }` to find thin wrappers
  - Tool: `grep` for `$testResult = $true` in `powershell/public/ad/**`

  **Acceptance Criteria**:
  - [ ] Inventory file exists at `.sisyphus/evidence/ad-check-inventory.json` with ≥270 entries.
  - [ ] Every entry has wrapper path, public function path, and category populated.
  - [ ] Count of `$testResult = $true` public functions is documented.

  **QA Scenarios**:
  ```
  Scenario: Inventory completeness
    Tool: Bash
    Steps: Run `find tests/ad -name '*.Tests.ps1' | wc -l` and `find powershell/public/ad -name '*.ps1' | wc -l`
    Expected: Counts match inventory entry counts within ±5
    Evidence: .sisyphus/evidence/task-1-inventory-counts.txt

  Scenario: Wrapper-to-function mapping accuracy
    Tool: Bash
    Steps: Sample 10 random inventory entries and verify wrapper calls the mapped public function
    Expected: All 10 samples match
    Evidence: .sisyphus/evidence/task-1-mapping-sample.txt
  ```

  **Commit**: NO

- [ ] 2. Define Assertion Rubric & Guidance Template Contract

  **What to do**:
  - Write the **moderate assertion rubric**: a check becomes a failing assertion if it represents a known security weakness with an industry-accepted best-practice threshold. Document explicit criteria: (a) maps to CIS control or Microsoft baseline, (b) threshold is documented and defensible, (c) false-positive risk is manageable in typical environments, (d) remediation is documentable.
  - Define the **lightweight guidance template**: mandatory sections `Why It Matters`, `Risk`, `Remediation`, `References`. Max length guidelines.
  - Define the **rich guidance template**: mandatory sections `Benefits`, `Impact`, `Remediation Steps` (numbered), `Impacted Resources` (table), `Related Links`. Max length and row-cap guidelines.
  - Define **severity mapping**: how severity (Critical/High/Medium/Low/Info) is derived from CIS/Microsoft baselines and internal risk assessment.
  - Define **deprecation criteria**: when an operational test overlaps ≥80% with a new security test, it goes on the deprecation list.
  - Document the **canonical emission pattern**: public function calls `Add-MtTestResultDetail -Description $desc -Result $result -Severity $sev` where `$desc` comes from adjacent `.md` template or inline markdown.
  - Store contract as `.sisyphus/evidence/ad-guidance-contract.md`.

  **Must NOT do**: Do not invent severity values without documented source. Do not define templates that require protocol changes.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: requires structured documentation and contract specification
  - Skills: `[]`

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 3, 4, 5, 6, 7, 8 | Blocked By: 1

  **References**:
  - Pattern: `powershell/public/Add-MtTestResultDetail.ps1` — function signature and behavior
  - Pattern: `website/docs/writing-tests/formatting-test-results.md` — existing guidance for writers
  - Pattern: `tests/Maester/Entra/Test-EntraRecommendations.Tests.ps1:24-75` — rich markdown inspiration
  - Pattern: `powershell/public/ad/domain/Test-MtAdMachineAccountQuota.ps1:56-71` — current AD emission pattern

  **Acceptance Criteria**:
  - [ ] Contract document exists at `.sisyphus/evidence/ad-guidance-contract.md`.
  - [ ] Rubric includes ≥4 explicit criteria for assertion conversion.
  - [ ] Both templates specify mandatory sections and max length constraints.
  - [ ] Severity mapping documents source-of-truth (CIS/Microsoft baseline mapping).

  **QA Scenarios**:
  ```
  Scenario: Contract completeness
    Tool: Bash
    Steps: grep -c "^## " .sisyphus/evidence/ad-guidance-contract.md
    Expected: ≥8 major sections (Rubric, Lightweight Template, Rich Template, Severity Mapping, Deprecation Criteria, Emission Pattern, Examples, Non-Goals)
    Evidence: .sisyphus/evidence/task-2-contract-sections.txt

  Scenario: Rubric testability
    Tool: Bash
    Steps: Apply rubric to 5 sample AD checks from inventory and classify each as assertion/operational/deferred
    Expected: All 5 classify unambiguously with documented justification
    Evidence: .sisyphus/evidence/task-2-rubric-sample.txt
  ```

  **Commit**: NO

- [ ] 3. Enrich Stable-Category Public Functions with Operational Guidance

  **What to do**:
  - Identify **stable categories** (unaffected by Plans 2/3/5): `computer`, `config`, `ou`, `printer`, `replication`, `schema`, `site`, `spn`.
  - For each public function in stable categories, evaluate against the rubric and template contract.
  - **Guidance-only enrichment** (no pass/fail changes): Update adjacent `.md` templates or inline `Add-MtTestResultDetail` calls with:
    - Lightweight template: `Why It Matters`, `Risk`, `Remediation`, `References`
    - Rich template (for high-severity checks): `Benefits`, `Impact`, `Remediation Steps`, `Impacted Resources`, `Related Links`
  - Ensure `-Severity` is explicitly passed to `Add-MtTestResultDetail` (or Pester tag `Severity:Value` is added).
  - Ensure `-Result` markdown uses `%TestResult%` placeholder only when `-GraphObjects` is passed.
  - Add `Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory` guards where missing for `$null` AD state.
  - Run `./powershell/tests/pester.ps1` after each batch.

  **Must NOT do**: Do not change pass/fail logic of existing tests. Do not add new dependencies. Do not modify Plan 2/3/5-dependent categories.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: many files, consistent pattern application
  - Skills: `[]`

  **Parallelization**: Can Parallel: YES (by subcategory) | Wave 2 | Blocks: — | Blocked By: 1, 2

  **References**:
  - Pattern: `powershell/public/ad/computer/**` — stable category example
  - Pattern: `powershell/public/ad/config/**` — stable category example
  - Pattern: `powershell/public/Add-MtTestResultDetail.ps1` — emission API
  - Pattern: `website/docs/writing-tests/formatting-test-results.md` — writer guidance

  **Acceptance Criteria**:
  - [ ] All public functions in stable categories emit guidance via `Add-MtTestResultDetail`.
  - [ ] `./powershell/tests/pester.ps1` passes.
  - [ ] At least one rich-template example exists per stable category.
  - [ ] No existing test ID has changed pass/fail semantics.

  **QA Scenarios**:
  ```
  Scenario: Guidance emission verification
    Tool: Bash
    Steps: Run Pester unit tests for 3 enriched public functions; capture Add-MtTestResultDetail call parameters
    Expected: Each call includes -Description or loads from adjacent .md; -Severity is present; -Result contains expected sections
    Evidence: .sisyphus/evidence/task-3-emission-verification.txt

  Scenario: No regression
    Tool: Bash
    Steps: Run ./powershell/tests/pester.ps1
    Expected: Exit code 0; zero AD-related failures
    Evidence: .sisyphus/evidence/task-3-pester-results.txt
  ```

  **Commit**: YES | Message: `feat(ad): add operational guidance to stable category checks` | Files: `powershell/public/ad/{computer,config,ou,printer,replication,schema,site,spn}/**`

- [ ] 4. Add Net-New Security Assertion Tests for Stable Categories

  **What to do**:
  - Using the classification matrix and rubric, identify stable-category checks that represent known security weaknesses with industry-accepted thresholds.
  - Create **net-new** public functions and test wrappers (new TestIds) — do not modify existing tests.
  - Examples of candidates:
    - Unconstrained delegation count should be zero (computer/security overlap)
    - SMBv1 enabled on DCs should be zero (domaincontroller — but this may be Plan 3 dependent; use stable alternative)
    - Stale enabled computer accounts exceeding threshold (computer)
    - Non-RFC1918 subnets indicating misconfiguration (site)
  - Each new test must:
    - Have a Pester fixture with pass/fail/boundary cases
    - Use the rich guidance template
    - Include `-Severity` tag
    - Include `Add-MtTestResultDetail` with full remediation context
    - Follow Maester naming conventions (`Test-MtAd*`, `AD-XXX-NN` ID format)
  - Maintain the deprecation list: if a new security test overlaps ≥80% with an existing operational test, document the overlap.

  **Must NOT do**: Do not modify existing test wrappers or public functions. Do not create tests for Plan 2/3-dependent categories. Do not assert without documented threshold and reference.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: implementing new checks with fixtures
  - Skills: `[]`

  **Parallelization**: Can Parallel: YES (by subcategory) | Wave 3 | Blocks: — | Blocked By: 1, 2, 3

  **References**:
  - Pattern: `tests/ad/security/Test-MtAdComputerNonDcUnconstrainedDelegationCount.Tests.ps1` — existing assertion-style test (checks non-DC computers should not have unconstrained delegation)
  - Pattern: `powershell/public/ad/security/Test-MtAdComputerNonDcUnconstrainedDelegationCount.ps1` — public function with assertion logic
  - Pattern: `tests/Maester/Entra/Test-EntraRecommendations.Tests.ps1:24-75` — rich guidance pattern
  - Standard: Maester test naming conventions from `AGENTS.md`

  **Acceptance Criteria**:
  - [ ] ≥10 net-new security assertion tests created across stable categories.
  - [ ] Each new test has a Pester fixture with pass/fail/boundary cases.
  - [ ] Deprecation list updated with ≥3 entries where new tests overlap existing operational tests.
  - [ ] `./powershell/tests/pester.ps1` passes including new tests.

  **QA Scenarios**:
  ```
  Scenario: New assertion test passes in compliant environment
    Tool: Bash
    Steps: Run Pester for a new assertion test against a synthetic fixture representing a compliant state
    Expected: Test passes; Add-MtTestResultDetail emits success guidance
    Evidence: .sisyphus/evidence/task-4-assertion-pass.txt

  Scenario: New assertion test fails in non-compliant environment
    Tool: Bash
    Steps: Run Pester for a new assertion test against a synthetic fixture representing a non-compliant state
    Expected: Test fails; Add-MtTestResultDetail emits failure guidance with remediation steps
    Evidence: .sisyphus/evidence/task-4-assertion-fail.txt

  Scenario: Deprecation list accuracy
    Tool: Bash
    Steps: Verify each deprecation list entry has a corresponding new test and documented overlap justification
    Expected: All entries justified with ≥80% overlap rationale
    Evidence: .sisyphus/evidence/task-4-deprecation-list.txt
  ```

  **Commit**: YES | Message: `feat(ad): add net-new security assertion tests for stable categories` | Files: `tests/ad/**`, `powershell/public/ad/**`

- [ ] 5. Gate: Verify Plan 2 & Plan 3 Stability for Dependent Categories

  **What to do**:
  - Confirm Plan 2 (LDAP collectors) has completed migration for categories: `passwordpolicy`, `group`, `domain`. **Inline stability criteria** (since upstream plan files are not present in repo):
    - Zero legacy `Get-AD*` calls (`Get-ADDefaultDomainPasswordPolicy`, `Get-ADFineGrainedPasswordPolicy`, `Get-ADGroup`, `Get-ADDomain`, `Get-ADUser`) in `powershell/public/ad/{passwordpolicy,group,domain}/**`.
    - All directory-state collection uses LDAP-based collectors with frozen object contracts.
  - Confirm Plan 3 (cross-platform transport) has completed GPO state composition for categories: `gpo`, `gpostate`, `domaincontroller`, `dns`. **Inline stability criteria**:
    - `Get-MtADGpoState` composes from LDAP + SYSVOL with canonical GPO report fields: `Name`, `GPOName`, `DisabledLinks`, `Enforcement`, `EnforcementEnabled`, `HasVersionMismatch`, `CpasswordFound`, `DefaultPasswordFound`, `PermissionsPresent`, `HasAuthenticatedUsers`, `HasDomainComputers`, `HasEnterpriseDomainControllers`, `HasInheritedPermissions`, `HasApplyGroupPolicyAce`, `HasDenyAce`.
    - No field renames or type changes in GPO state contracts since Plan 3 baseline.
  - Verify no legacy `Get-AD*` calls remain in dependent-category public functions.
  - Verify GPO state contracts from Plan 3 are stable (no field renames or type changes).
  - **Plan 5 overlap check**: For `security`, `dacl`, `trust`, `user` categories, inspect whether tier-model guidance already exists in public functions. If yes, document harmonization strategy (reference, don't duplicate).
  - Document any remaining instability or blockers.
  - If stability is not confirmed, document deferred categories and proceed with Tasks 6–7 only for confirmed-stable dependent categories.

  **Must NOT do**: Do not begin modifying dependent-category files before stability is confirmed. Do not assume Plan 2/3 completion without verification.

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: requires cross-plan dependency verification and risk assessment
  - Skills: `[]`

  **Parallelization**: Can Parallel: NO | Wave 4 | Blocks: 6, 7 | Blocked By: Plan 2, Plan 3

  **References**:
  - Plan 2 stability criteria (inlined in task description above): zero legacy `Get-AD*` calls in `powershell/public/ad/{passwordpolicy,group,domain}/**`
  - Plan 3 stability criteria (inlined in task description above): GPO state contracts stable with canonical field set
  - Pattern: `powershell/public/ad/passwordpolicy/**` — Plan 2 affected category
  - Pattern: `powershell/public/ad/gpo/**` — Plan 3 affected category

  **Acceptance Criteria**:
  - [ ] Plan 2 stability confirmed for `passwordpolicy`, `group`, `domain` (zero legacy `Get-AD*` calls).
  - [ ] Plan 3 stability confirmed for `gpo`, `gpostate`, `domaincontroller`, `dns` (stable GPO state contracts).
  - [ ] Stability report stored at `.sisyphus/evidence/plan-2-3-stability-report.md`.

  **QA Scenarios**:
  ```
  Scenario: Plan 2 legacy call verification
    Tool: Bash
    Steps: grep -r "Get-ADDefaultDomainPasswordPolicy\|Get-ADFineGrainedPasswordPolicy\|Get-ADGroup\|Get-ADDomain" powershell/public/ad/{passwordpolicy,group,domain}/
    Expected: Zero matches (or matches documented as exceptions)
    Evidence: .sisyphus/evidence/task-5-plan2-legacy-check.txt

  Scenario: Plan 3 contract stability
    Tool: Bash
    Steps: Read `powershell/public/Get-MtADGpoState.ps1` (or equivalent GPO state composer) and verify it exposes all fields in the inline contract: Name, GPOName, DisabledLinks, Enforcement, EnforcementEnabled, HasVersionMismatch, CpasswordFound, DefaultPasswordFound, PermissionsPresent, HasAuthenticatedUsers, HasDomainComputers, HasEnterpriseDomainControllers, HasInheritedPermissions, HasApplyGroupPolicyAce, HasDenyAce
    Expected: All 15 fields are present and typed correctly in the output object
    Evidence: .sisyphus/evidence/task-5-plan3-contract-check.txt
  ```

  **Commit**: NO

- [ ] 6. Enrich Dependent-Category Public Functions with Operational Guidance

  **What to do**:
  - Same approach as Task 3, but for Plan 2/3-stable dependent categories: `passwordpolicy`, `group`, `domain`, `gpo`, `gpostate`, `domaincontroller`, `dns`.
  - Also evaluate Plan 5 overlap for `security`, `dacl`, `trust`, `user`: if Plan 5 has already added tier-model guidance, do not duplicate — instead harmonize or reference Plan 5 content.
  - Apply lightweight or rich template based on severity mapping.
  - Add `Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory` guards where missing.
  - Run `./powershell/tests/pester.ps1` after each batch.

  **Must NOT do**: Do not duplicate Plan 5 tier-model guidance. Do not change existing pass/fail logic.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: many files, consistent pattern application
  - Skills: `[]`

  **Parallelization**: Can Parallel: YES (by subcategory) | Wave 5 | Blocks: — | Blocked By: 1, 2, 5

  **References**:
  - Pattern: `powershell/public/ad/passwordpolicy/**` — dependent category
  - Pattern: `powershell/public/ad/gpo/**` — dependent category
  - Plan 5 overlap criteria (inlined): For `security`, `dacl`, `trust`, `user` categories, check if tier-model guidance already exists. If yes, harmonize by referencing rather than duplicating.

  **Acceptance Criteria**:
  - [ ] All public functions in dependent categories emit guidance via `Add-MtTestResultDetail`.
  - [ ] `./powershell/tests/pester.ps1` passes.
  - [ ] Plan 5 overlap documented and harmonized (no duplication).

  **QA Scenarios**:
  ```
  Scenario: Guidance emission verification
    Tool: Bash
    Steps: Run Pester unit tests for 3 enriched dependent-category public functions
    Expected: Each call includes expected guidance sections; no Plan 5 duplication
    Evidence: .sisyphus/evidence/task-6-emission-verification.txt

  Scenario: No regression
    Tool: Bash
    Steps: Run ./powershell/tests/pester.ps1
    Expected: Exit code 0; zero AD-related failures
    Evidence: .sisyphus/evidence/task-6-pester-results.txt
  ```

  **Commit**: YES | Message: `feat(ad): add operational guidance to dependent category checks` | Files: `powershell/public/ad/{passwordpolicy,group,domain,gpo,gpostate,domaincontroller,dns,security,dacl,trust,user}/**`

- [ ] 7. Add Net-New Security Assertion Tests for Dependent Categories

  **What to do**:
  - Same approach as Task 4, but for dependent categories after Plan 2/3 stability is confirmed.
  - Identify security weakness candidates:
    - Weak password policy settings (passwordpolicy)
    - Privileged group membership anomalies (group)
    - Domain functional level below recommended (domain)
    - GPO with Cpassword or default passwords (gpo/gpostate)
    - SMBv1 enabled on DCs (domaincontroller)
    - DNS zone transfer misconfiguration (dns)
  - Each new test: Pester fixture, rich template, `-Severity`, `Add-MtTestResultDetail`, Maester naming.
  - Update deprecation list for overlaps.

  **Must NOT do**: Do not create tests for categories where Plan 2/3 stability is not confirmed.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` — Reason: implementing new checks with fixtures
  - Skills: `[]`

  **Parallelization**: Can Parallel: YES (by subcategory) | Wave 5 | Blocks: — | Blocked By: 1, 2, 5, 6

  **References**:
  - Pattern: `tests/ad/security/Test-MtAdComputerNonDcUnconstrainedDelegationCount.Tests.ps1` — assertion pattern
  - Pattern: `tests/Maester/Entra/Test-EntraRecommendations.Tests.ps1:24-75` — rich guidance

  **Acceptance Criteria**:
  - [ ] ≥10 net-new security assertion tests created across dependent categories.
  - [ ] Each new test has a Pester fixture with pass/fail/boundary cases.
  - [ ] Deprecation list updated.
  - [ ] `./powershell/tests/pester.ps1` passes including new tests.

  **QA Scenarios**:
  ```
  Scenario: New assertion test passes in compliant environment
    Tool: Bash
    Steps: Run Pester for a new assertion test against synthetic fixture
    Expected: Test passes; guidance emitted correctly
    Evidence: .sisyphus/evidence/task-7-assertion-pass.txt

  Scenario: New assertion test fails in non-compliant environment
    Tool: Bash
    Steps: Run Pester for a new assertion test against synthetic fixture
    Expected: Test fails; remediation guidance emitted
    Evidence: .sisyphus/evidence/task-7-assertion-fail.txt
  ```

  **Commit**: YES | Message: `feat(ad): add net-new security assertion tests for dependent categories` | Files: `tests/ad/**`, `powershell/public/ad/**`

- [ ] 8. Regenerate Documentation & Finalize Deprecation List

  **What to do**:
  - Run command docs regeneration: `./build/Update-CommandReference.ps1` (generates `website/docs/commands/**` from comment-based help).
  - Run test docs regeneration: `cd website && npm run generate-test-docs` (runs `node scripts/generate-test-docs.mjs`).
  - Verify generated docs under `website/docs/commands/` and `website/docs/tests/` reflect changes.
  - Finalize the deprecation list with: operational test ID, new security test ID, overlap justification, recommended migration path, timeline.
  - Store final deprecation list at `.sisyphus/evidence/ad-deprecation-list.md`.
  - Run `./build/Build-MaesterModule.ps1` and `./build/Test-MaesterModuleOutput.ps1`.
  - Run `./powershell/tests/pester.ps1`.
  - Verify report rendering: build report app (`cd report && npm ci && npm run build`) and inspect HTML output for both lightweight and rich markdown examples.
  - Ensure any E2E validation references in generated docs align with Plan 9's canonical topology and three-track mandatory validation process.

  **Must NOT do**: Do not hand-edit generated docs. Do not finalize deprecation list without overlap justification.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: documentation and list finalization
  - Skills: `[]`

  **Parallelization**: Can Parallel: NO | Wave 6 | Blocks: F1–F4 | Blocked By: 3, 4, 6, 7

  **References**:
  - Command: `./build/Build-MaesterModule.ps1` — module build
  - Command: `./build/Test-MaesterModuleOutput.ps1` — module validation
  - Command: `./powershell/tests/pester.ps1` — unit tests
  - Rule: `AGENTS.md` — "Generated content — regenerate, never hand-edit"

  **Acceptance Criteria**:
  - [ ] Generated docs reflect all updated public functions.
  - [ ] Deprecation list finalized with ≥3 entries and full justification.
  - [ ] `./build/Build-MaesterModule.ps1` succeeds.
  - [ ] `./build/Test-MaesterModuleOutput.ps1` validates.
  - [ ] `./powershell/tests/pester.ps1` passes.
  - [ ] Report rendering verified for both lightweight and rich markdown.

  **QA Scenarios**:
  ```
  Scenario: Documentation regeneration
    Tool: Bash
    Steps: Run `./build/Update-CommandReference.ps1` and `cd website && npm run generate-test-docs`; diff generated files against baseline
    Expected: Only expected files changed; no hand-edits detected; `website/docs/commands/` and `website/docs/tests/` reflect updated public functions
    Evidence: .sisyphus/evidence/task-8-docs-diff.txt

  Scenario: Report rendering
    Tool: Bash
    Steps: Build report app (cd report && npm ci && npm run build); inspect HTML output for rich and lightweight guidance sections
    Expected: Both templates render correctly without markdown leakage or truncation
    Evidence: .sisyphus/evidence/task-8-report-render.html
  ```

  **Commit**: YES | Message: `docs(ad): regenerate docs and finalize deprecation list` | Files: `website/docs/commands/**`, `website/docs/tests/**`, `.sisyphus/evidence/ad-deprecation-list.md`

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.

- [ ] F1. Plan Compliance Audit

  **Agent**: oracle
  **What to verify**:
  - All enriched public functions use `Add-MtTestResultDetail` as the canonical emission layer (no wrapper-level guidance duplication).
  - No existing test ID has changed pass/fail semantics.
  - Assertion rubric from Task 2 was applied consistently to all net-new security tests.
  - Deprecation list is complete with ≥3 entries and full overlap justification.
  - Severity values are sourced from CIS/Microsoft baselines or documented internal risk assessment (not invented ad-hoc).

  **Steps**:
  1. Read `.sisyphus/evidence/ad-check-inventory.json` and sample 20 entries.
  2. Read `.sisyphus/evidence/ad-guidance-contract.md` and verify rubric criteria.
  3. Read `.sisyphus/evidence/ad-deprecation-list.md` and verify entries.
  4. Inspect 10 modified public functions for `Add-MtTestResultDetail` usage and severity sourcing.
  5. Inspect 5 net-new security tests for rubric compliance.

  **Expected**: All samples pass compliance checks. Any deviation is documented with justification.
  **Evidence**: `.sisyphus/evidence/f1-compliance-audit.md`

- [ ] F2. Code Quality Review

  **Agent**: unspecified-high
  **What to verify**:
  - Pester conventions followed (Describe/It naming, Should assertions, Because messages).
  - `Add-MtTestResultDetail` usage is correct (Description/Result markdown valid, Severity present, no malformed `%TestResult%` placeholders).
  - No AI slop patterns (hardcoded values, copy-paste drift, inconsistent formatting).
  - Maester naming conventions followed (`Test-MtAd*`, `AD-XXX-NN` IDs).
  - Markdown in `.md` templates and inline strings is valid (no unclosed backticks, broken links, malformed tables).

  **Steps**:
  1. Run `Invoke-ScriptAnalyzer` on all modified `powershell/public/ad/**/*.ps1` files.
  2. Run `Invoke-ScriptAnalyzer` on all new `tests/ad/**/*.Tests.ps1` files.
  3. Validate markdown syntax in all new/adjacent `.md` template files.
  4. Check for consistent naming across all new tests.

  **Expected**: Zero PSScriptAnalyzer warnings for modified files. All markdown valid. All naming consistent.
  **Evidence**: `.sisyphus/evidence/f2-quality-review.txt`

- [ ] F3. Real QA Execution

  **Agent**: unspecified-high
  **What to verify**:
  - Unit tests pass.
  - Module builds successfully.
  - Report renders both lightweight and rich markdown correctly.
  - New assertion tests fail correctly against non-compliant fixtures.

  **Steps**:
  1. Run `./powershell/tests/pester.ps1` and capture exit code + failure count.
  2. Run `./build/Build-MaesterModule.ps1` and capture exit code.
  3. Run `./build/Test-MaesterModuleOutput.ps1` and capture exit code.
  4. Build report app: `cd report && npm ci && npm run build`.
  5. Run a synthetic test cycle that exercises both lightweight and rich guidance templates; capture HTML output.
  6. Run 3 net-new security assertion tests against non-compliant synthetic fixtures; verify they fail with expected guidance.

  **Expected**: All commands exit 0. HTML report shows both template types without markdown leakage or truncation. New assertion tests fail with correct remediation guidance.
  **Evidence**: `.sisyphus/evidence/f3-qa-execution.txt`, `.sisyphus/evidence/f3-report-render.html`

- [ ] F4. Scope Fidelity Check

  **Agent**: deep
  **What to verify**:
  - No protocol, transport, or collector layer changes (Plans 1–3 boundaries respected).
  - No test wrapper guidance duplication (public functions remain canonical).
  - Plan 2/3/5 dependencies respected (no modifications to unstable categories).
  - Scope boundaries enforced (no new non-AD check families, no broad ID churn).

  **Steps**:
  1. Diff all modified files against `main` baseline; categorize changes by layer (protocol, collector, public function, test wrapper, docs).
  2. Verify zero changes in `powershell/internal/ad/` (protocol layer) unless explicitly justified.
  3. Verify all guidance emission occurs in `powershell/public/ad/**` (not test wrappers).
  4. Cross-check modified categories against dependency matrix; verify no Plan 2/3-unstable categories were modified.
  5. Verify no existing test IDs were renamed or removed.

  **Expected**: All changes are within scope (public functions + test wrappers + docs). Zero protocol-layer changes. Zero wrapper-level guidance duplication. Zero unauthorized category modifications.
  **Evidence**: `.sisyphus/evidence/f4-scope-fidelity.md`

## Commit Strategy
- Wave 2 commit: `feat(ad): add operational guidance to stable category checks`
- Wave 3 commit: `feat(ad): add net-new security assertion tests for stable categories`
- Wave 5 commit (dependent guidance): `feat(ad): add operational guidance to dependent category checks`
- Wave 5 commit (dependent assertions): `feat(ad): add net-new security assertion tests for dependent categories`
- Wave 6 commit: `docs(ad): regenerate docs and finalize deprecation list`
- No commits for inventory, rubric, or stability gate tasks (research/planning artifacts).

## Success Criteria
- All ~270 AD files are inventoried and classified.
- Every **stable-category** public function emits operational guidance via `Add-MtTestResultDetail`.
- ≥10 net-new security assertion tests exist in **stable categories**.
- Deprecation list documents ≥3 operational tests with overlap justification.
- `./powershell/tests/pester.ps1`, `./build/Build-MaesterModule.ps1`, and `./build/Test-MaesterModuleOutput.ps1` all pass.
- Report renders both lightweight and rich markdown correctly.
- **Conditional**: If Plan 2/3 stability gate passes, dependent-category guidance enrichment and ≥10 additional net-new assertion tests are also completed.
- **If gate fails**: Deferred categories and their blocked tasks are documented with a follow-on plan reference.
- Final verification wave (F1–F4) receives explicit user approval.
- Plan 9 E2E alignment: any live E2E validation of new or enriched checks follows the three-track mandatory process (preflight gate, protocol probe matrix, public E2E runner matrix) against the canonical lab topology, with machine-readable evidence artifacts for every mandatory row.

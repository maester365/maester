# Cross-Platform Active Directory Protocol Integration and Targeting

## TL;DR
> **Summary**: Remove Maester's ActiveDirectory, GroupPolicy, and DnsServer module dependencies by introducing internal LDAP, SYSVOL/SMB, and WinRM/PSRP adapters while preserving existing AD check contracts. Support one credentialed forest/domain/server target per run, document every selector combination, and merge distinct runs with explicit target provenance.
> **Deliverables**:
> - Dedicated `ad-multiforest-targeting` branch aligned to refreshed `main`
> - Cross-platform LDAP transport using `System.DirectoryServices.Protocols`
> - Credentialed SYSVOL transport using Windows native SMB or Unix `smbclient`
> - Credentialed WinRM/PSRP management backend for DNS WMI and live SMB configuration
> - Module-free AD/GPO/DNS collectors preserving current result shapes
> - Complete targeting/authentication documentation and merge workflow
> - Windows PowerShell 5.1, Windows PowerShell 7, and Ubuntu PowerShell 7 E2E evidence
> **Effort**: XL
> **Parallel**: YES - 10 waves
> **Critical Path**: 1 → 2 → 3 → 4 → 5 → 6/7 → 8/9/10 → 11/12/13 → 14 → 15/16 → 17 → 18/19 → 20 → 20b
> **Parallel Tracks**: Plan 5 research (Tasks 21–22), Plan 7 (SACL cache), and Plan 8 (least-privilege matrix) can execute in parallel with Tasks 1–20.

## Pre-Flight: Plan Selection & Branch Setup

### Plan Hierarchy
This file is the **canonical execution plan** for Tasks 1–20. Plans `01-ad-protocol-foundation.md` through `04-integration-docs-and-e2e.md` are **reference views** only — they segment this master plan by topic for readability but lack the per-task QA scenarios, agent profiles, and dependency matrices required for execution. **Always execute from this file.**

> **Plan 4 Status**: Tasks 16–20 (baseline validation of the legacy module-based approach) are complete. **Task 20b (re-validation against protocol-migrated code)** must run after Plans 1–3 are implemented.

Plan `05-tier-model-alignment.md` is a **separate dependent workstream** (Tasks 21–26). It can begin research (Tasks 21–22) in parallel with protocol work, but implementation (Tasks 23–25) requires Plan 2 query catalog stability, and validation (Task 26) requires Plan 4 E2E lab availability.

Plans `07-ad-sacl-cache-stability.md` and `08-ad-least-privilege-matrix.md` are **discrete workstreams** that can execute in parallel with Plans 1–3. They do not depend on the protocol migration and are intentionally scoped to avoid overlap.

### Execution Policy
- **Sequential plan execution**: Do not automatically start all plans. Each `/start-work` session targets **one plan at a time** as explicitly requested by the user.
- **Suggested order**:
  1. Master plan Tasks 1–20 (protocol migration + baseline docs/E2E)
  2. Plan 7 (SACL cache) and Plan 8 (least-privilege matrix) — in parallel with Tasks 1–20
  3. Plan 5 research (Tasks 21–22) — in parallel with Tasks 1–20
  4. Plan 5 implementation (Tasks 23–25) — after Plan 2 is stable
  5. Plan 4 Task 20b (E2E Re-Validation) — after Plans 1–3 are complete
  6. Plan 5 validation (Task 26) — after Plan 4 Task 20b

### Branch Setup (Required Before Task 1)
1. Ensure `main` is clean and up to date with `upstream/main`.
2. From `main`, create or reset the feature branch `ad-multiforest-targeting`.
3. Remove rejected experiment files if present: `Set-MtADTarget.ps1`, `ActiveDirectoryTargeting.ps1`, `ActiveDirectoryTargeting.Tests.ps1`, and any target map/list/current-key exports.
4. Preserve `docs/e2e-ad-testing-guide.md` and all plan files.
5. Record baseline diff before transport changes begin.

> **Guardrail**: Do not commit to `main`. Do not push without explicit request.

## Context
### Original Request
- Refresh from upstream and review Maester's Active Directory integrations.
- Compare collection with `jakehildreth/Locksmith2`.
- Remove the ActiveDirectory module dependency as a core objective.
- Continue supporting forest/domain combinations and explicit targeting with adequate user documentation.
- Remove GroupPolicy and DnsServer module dependencies as confirmed scope.
- Support cross-platform PowerShell 7, full explicit credential parity, and preserve Windows PowerShell 5.1.
- Minimize core Maester changes; do not introduce `Set-MtADTarget`.
- Validate against a purpose-built Azure environment and merge separate target runs.

### Interview Summary
- One effective target per `Connect-Maester`/`Invoke-Maester` cycle; multiple domains/forests use separate runs and `Merge-MtMaesterResult`.
- Public selectors: `ActiveDirectoryForest`, `ActiveDirectoryDomain`, `ActiveDirectoryServer`, and `ActiveDirectoryCredential`.
- Supported combinations: ambient; each selector alone; Forest+Domain; Forest+Server; Domain+Server; Forest+Domain+Server; Credential with any explicit combination. Every supplied value must resolve to the same target.
- Forest-only means root-domain analysis plus forest-wide Configuration/Partitions/trust data.
- LDAP uses `System.DirectoryServices.Protocols`; explicit credentials require validated LDAPS or StartTLS and fail closed.
- SYSVOL uses native SMB mapping on Windows and `smbclient` protected auth files/ccaches on Unix.
- DNS/file-backed zone/root-hint and live SMB state use credentialed WinRM/PSRP; non-Windows requires PSWSMan.
- Existing collector/result shapes remain stable; GPO report compatibility uses a canonical superset with current producer and consumer aliases.
- Result metadata receives a non-secret target label so merged AD runs remain distinguishable.

### Metis Review (gaps addressed)
- Remove the current uncommitted target registry before transport work.
- Freeze target semantics and object contracts before implementation.
- Replace all Windows-only `DirectoryEntry`/`DirectorySearcher` paths, not only module cmdlets.
- Preserve exact bool/DateTime/TimeSpan/SID/DNS RecordData contracts and explicitly fetch `dNSHostName`.
- Treat LDAP, SMB, and WinRM credentials as one security matrix; redact and clean all secret material.
- Replace or retire all build/docs scripts that assume removed modules.
- Validate absence of legacy calls structurally and run live Windows/Ubuntu tests without the removed modules.

## Work Objectives
### Core Objective
Replace Windows module-backed AD collection with protocol-backed internal adapters while leaving Maester's opt-in execution and public analysis functions intact.

### Deliverables
- Target resolver and flat AD session context with no public switching command or registry.
- LDAP client primitives, query catalog, ranged group membership, ACL parsing, and contract normalizers.
- Domain, DACL, GPO, DNS, and SMB state collectors with current public shapes.
- Secure cross-platform credential propagation over LDAP, SMB, and WinRM/PSRP.
- Updated analysis helpers with zero `Get-AD*`/`Get-GPO*`/`Get-DnsServer*` usage.
- Target provenance and documented separate-run merge examples.
- Updated runner/build/docs and five-VM Azure E2E topology.

### Definition of Done
- Product and AD build paths contain zero ActiveDirectory, GroupPolicy, or DnsServer module imports/calls.
- No product `Set-MtADTarget`, `TargetMap`, `CurrentTargetKey`, or multi-target session registry remains.
- Full Pester harness, module build, and module-output validation exit `0`.
- Contract fixtures prove all existing state properties/types remain available.
- Windows PS5.1/PS7 and Ubuntu PS7 execute AD tests against live targets without the three removed modules.
- Separate root-domain, child-domain, and second-forest results merge with unique target provenance.
- Azure resources and temporary credentials/auth files are fully removed.

### Must Have
- Existing `Connect-Maester -Service ActiveDirectory` opt-in and `-Service All` exclusion.
- Flat single-target connection state; no `Invoke-Maester` target loop.
- Secure LDAP for explicit credentials with certificate validation.
- Paging cookies on one LDAP session; ranged multi-value retrieval; bounded searches and file parsing.
- Existing collector keys and consumer-visible types.
- Exact DNS shapes for A/NS/SRV/SOA and generic record metadata, including `RootDNSServers` normalization.
- Exact SMB booleans and `DCName`.
- Credential-free logs, cache keys, results, evidence, process arguments, and retained temp files.

### Must NOT Have
- No ActiveDirectory, GroupPolicy, or DnsServer module dependency.
- No ADSI, `DirectoryEntry`, or `DirectorySearcher` product path.
- No `Set-MtADTarget`, target map, target list, or in-run multi-target orchestration.
- No insecure simple LDAP bind, certificate bypass, plaintext credential persistence, or password process arguments.
- No Graph/Azure dependency in product collection, automatic remediation, or full `Get-GPOReport` XML recreation.
- No silent null coercion for missing contract fields and no generated-doc hand edits.

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Tests-after with protocol fixtures, Pester mocks, parser/PSScriptAnalyzer, full module harness, package validation, and live E2E.
- Every task captures evidence under `.sisyphus/evidence/task-{N}-{slug}.{ext}`.
- Fixtures contain synthetic directory/DNS/GPO data only; credentials are generated at runtime and never committed.

## Execution Strategy
### Parallel Execution Waves
Wave 1: Tasks 1–3 (branch/scope reset, contracts, packaging)
Wave 2: Tasks 4–5 (LDAP transport and target resolver)
Wave 3: Tasks 6–7 (normalizers/query catalog and domain/DACL collectors)
Wave 4: Tasks 8–10 (GPO metadata, SYSVOL, GPO state)
Wave 5: Tasks 11–13 (PSRP management, DNS, SMB runtime)
Wave 6: Tasks 14–16 (follow-on migration, provenance/merge, runner/docs)
Wave 7: Task 17 (full local validation)
Wave 8: Task 18 (Azure deployment)
Wave 9: Task 19 (platform E2E)
Wave 10: Task 20 (combination/merge validation and cleanup)

### Dependency Matrix
| Task | Blocked By | Blocks |
|---|---|---|
| 1 | None | 2, 3 |
| 2 | 1 | 4, 6, 7, 8, 9, 11, 12, 13, 14 |
| 3 | 1 | 4, 9, 11, 16 |
| 4 | 2, 3 | 5, 6, 7, 8, 12, 14 |
| 5 | 4 | 6, 7, 8, 9, 11, 12, 13, 14, 15 |
| 6 | 4, 5 | 7, 8, 12, 14 |
| 7 | 4, 5, 6 | 14, 17 |
| 8 | 4, 5, 6 | 10, 14 |
| 9 | 3, 5 | 10 |
| 10 | 8, 9 | 14, 17 |
| 11 | 3, 5 | 12, 13 |
| 12 | 4, 5, 6, 11 | 17 |
| 13 | 5, 11 | 17 |
| 14 | 5, 6, 7, 10 | 17 |
| 15 | 5 | 17, 19, 20 |
| 16 | 3, 15 | 17, 18, 19, 20 |
| 17 | 7, 10, 12, 13, 14, 15, 16 | 18, 19 |
| 18 | 16, 17 | 19, 20 |
| 19 | 15, 16, 17, 18 | 20 |
| 20 | 18, 19 | Final verification |

### Agent Dispatch Summary
| Wave | Tasks | Categories |
|---|---:|---|
| 1 | 3 | deep, writing |
| 2 | 2 | deep |
| 3 | 2 | deep, unspecified-high |
| 4 | 3 | deep, unspecified-high |
| 5 | 3 | deep, unspecified-high |
| 6 | 3 | deep, writing |
| 7 | 1 | deep |
| 8 | 1 | unspecified-high |
| 9 | 1 | unspecified-high |
| 10 | 1 | unspecified-high |

## TODOs
> Implementation + test is one task. Every task has executable happy/failure QA and evidence.

- [ ] 1. Align the dedicated branch and remove the rejected target-registry experiment
  **What to do**:
  - Re-verify `main`/`upstream/main`, rename `codex/ad-multiforest-targeting` to `ad-multiforest-targeting`, and preserve all tracked/untracked work.
  - Restore product source to the `main` baseline plus merged PR #2002 behavior, removing `Set-MtADTarget`, `ActiveDirectoryTargeting.ps1`, target maps/lists/current keys, and their exports/tests.
  - Preserve `docs/e2e-ad-testing-guide.md` and this plan. Record the baseline diff before transport changes.
  **Must NOT do**: Do not checkout/edit `main`, hard reset, push, or discard user files.
  **Agent Profile**: Category `deep`; Skills [`git-master`] for safe branch/history inspection.
  **Parallelization**: NO | Wave 1 | Blocks 2,3 | Blocked by none.
  **References**: `powershell/public/Set-MtADTarget.ps1`; `powershell/internal/ActiveDirectoryTargeting.ps1`; `powershell/Maester.psd1:58-70`; PR `https://github.com/maester365/maester/pull/2002`.
  **Acceptance Criteria**:
  - `git branch --show-current` is `ad-multiforest-targeting`; `main` is an ancestor.
  - Product scan returns zero `Set-MtADTarget|TargetMap|CurrentTargetKey`; PR #2002 `Get-MtADDomainState -ComputerName`/Configuration behavior remains.
  **QA Scenarios**:
  ```
  Scenario: Branch rename preserves working state
    Tool: Bash (git-master)
    Steps: Hash plan/guide and capture status before/after rename; verify merge-base.
    Expected: Hashes/status content preserved; branch name exact; main unchanged.
    Evidence: .sisyphus/evidence/task-1-branch.txt
  Scenario: Rejected architecture is removed
    Tool: Grep + pwsh
    Steps: Scan product/manifest; import module and query Set-MtADTarget.
    Expected: Zero symbols/command; PR #2002 focused tests still pass.
    Evidence: .sisyphus/evidence/task-1-scope-reset.txt
  ```
  **Commit**: NO

- [ ] 2. Freeze target, transport, and object-shape contracts as executable fixtures
  **What to do**:
  - Add synthetic fixtures/contracts for Domain, Forest, RootDSE, users, computers (including `dNSHostName`), groups/SID.Value, DCs, trusts, password policies/TimeSpan, FGPP, configuration/schema, DACLs, GPOs/reports/links, DNS, and SMB.
  - Canonicalize GPO reports as a compatibility superset: `Name`, `GPOName`, `DisabledLinks`, `Enforcement`, `EnforcementEnabled`, `HasVersionMismatch`, `CpasswordFound`, `DefaultPasswordFound`, `PermissionsPresent`, `HasAuthenticatedUsers`, `HasDomainComputers`, `HasEnterpriseDomainControllers`, `HasInheritedPermissions`, `HasApplyGroupPolicyAce`, `HasDenyAce`.
  - Define selector matrix and resolution: ambient; Forest(root domain); Domain; Server; all aligned combinations; optional Credential. Reject conflicting values and arrays.
  - Define `TargetLabel = <forest>/<domain>@<server>` and secret-free capability/error metadata.
  **Must NOT do**: Do not alter check thresholds/results while freezing schemas.
  **Agent Profile**: Category `deep`; Skills [] (contract/static analysis).
  **Parallelization**: NO | Wave 1 | Blocks 4,6–14 | Blocked by 1.
  **References**: `powershell/public/Get-MtADDomainState.ps1`; `Get-MtADGpoState.ps1`; `powershell/public/ad/**`; `powershell/tests/functions/ActiveDirectoryOptIn.Tests.ps1`.
  **Acceptance Criteria**:
  - Fixture contract tests enumerate every property/type consumed by shipped AD checks.
  - GPO producer/consumer mismatches are represented by both aliases; DNS typed A/NS/SRV/SOA and SMB booleans are fixed.
  **QA Scenarios**:
  ```
  Scenario: Baseline consumers accept fixtures
    Tool: Bash (pwsh/Pester)
    Steps: Mock collectors with each fixture and run representative checks from every AD category.
    Expected: No missing-property/type errors; baseline decisions unchanged.
    Evidence: .sisyphus/evidence/task-2-contracts.txt
  Scenario: Malformed fixture fails loudly
    Tool: Bash (pwsh/Pester)
    Steps: Remove SID.Value, TimeSpan, DNS RecordData, and GPO alias fields in separate cases.
    Expected: Contract validator identifies exact missing/invalid field.
    Evidence: .sisyphus/evidence/task-2-contract-errors.txt
  ```
  **Commit**: NO

- [ ] 3. Define and package protocol prerequisites without legacy modules
  **What to do**:
  - Establish exact private layout: `powershell/internal/ad/protocol/` (LDAP), `powershell/internal/ad/queries/` (directory query catalog), `powershell/internal/ad/transport/` (SYSVOL/PSRP), and fixtures under `powershell/tests/fixtures/ActiveDirectory/`.
  - Verify/load `System.DirectoryServices.Protocols` on Windows PS5.1 and PS7 Windows/Ubuntu; package only assemblies not guaranteed by supported runtimes.
  - Add prerequisite detection for PSWSMan/WSMan on Unix and `smbclient`; Windows uses native WinRM and credentialed `New-PSDrive`/UNC.
  - Update build/module output to include protocol assets/fixtures but no ActiveDirectory, GroupPolicy, or DnsServer requirement.
  - Define version floors, supported auth matrix, and actionable prerequisite errors.
  **Must NOT do**: No auto-install during module import, unreviewed binary vendoring, or LGPL/GPL runtime dependency.
  **Agent Profile**: Category `deep`; Skills [] (packaging/platform compatibility).
  **Parallelization**: YES | Wave 1 | Blocks 4,9,11,16 | Blocked by 1.
  **References**: `powershell/Maester.psd1:18,36`; `build/Build-MaesterModule.ps1`; PSWSMan docs; .NET `LdapConnection` docs.
  **Acceptance Criteria**:
  - Build succeeds on Windows PS5.1 and PS7 with no legacy modules installed.
  - Unix prerequisite checker reports exact missing PSWSMan/smbclient actions without mutating host.
  **QA Scenarios**:
  ```
  Scenario: Supported runtimes load protocol assets
    Tool: Bash (pwsh/powershell)
    Steps: Import built module on PS5.1, Windows PS7, Ubuntu PS7; load LDAP types.
    Expected: Imports/types succeed without removed modules.
    Evidence: .sisyphus/evidence/task-3-runtime-matrix.txt
  Scenario: Missing prerequisite is actionable
    Tool: Bash (pwsh fixture)
    Steps: Hide PSWSMan/smbclient from discovery.
    Expected: Targeted capability error; no partial session or install attempt.
    Evidence: .sisyphus/evidence/task-3-prereq-error.txt
  ```
  **Commit**: NO

- [ ] 4. Implement the secure LDAP protocol adapter
  **What to do**:
  - Implement private functions in `powershell/internal/ad/protocol/`: `New-MtLdapConnection`, `Get-MtLdapRootDse`, `Invoke-MtLdapSearch`, `Get-MtLdapRangedValue`, `ConvertFrom-MtLdapValue`, and `ConvertFrom-MtLdapSecurityDescriptor` (one function per file).
  - Add private `LdapConnection` factory, RootDSE read, base/one-level/subtree search, paged search, ranged attribute retrieval, DN-safe filter escaping, controls, timeout/cancellation, and deterministic disposal.
  - Explicit Credential path: try validated LDAPS 636, then validated StartTLS 389; fail closed if neither is secure. Integrated auth uses Negotiate where supported.
  - Request `nTSecurityDescriptor` with appropriate controls and parse via `RawSecurityDescriptor` into existing ACE strings/types.
  - Never store credentials in connection metadata/cache; keep only a private in-memory reference cleared on disconnect/module reset.
  **Must NOT do**: No Basic bind without TLS, certificate bypass, ADSI/DirectoryEntry/Searcher, or raw credential logging.
  **Agent Profile**: Category `deep`; Skills [] (security-sensitive protocol core).
  **Parallelization**: NO | Wave 2 | Blocks 5–8,12,14 | Blocked by 2,3.
  **References**: .NET `LdapConnection`, `StartTransportLayerSecurity`, `PageResultRequestControl`; MS-ADTS paging; Locksmith2 searcher design at commit `ac2476...` (concept only).
  **Acceptance Criteria**:
  - Unit fixtures prove paging cookie reuse, range completion, escaping, TLS/cert failure, timeout, and disposal.
  - Secret scan of verbose/errors/cache/results finds no credential material.
  **QA Scenarios**:
  ```
  Scenario: Secure paged credentialed search
    Tool: Bash (pwsh/Pester protocol fake)
    Steps: Bind LDAPS with fake cert chain, return two page cookies and ranged members.
    Expected: One connection/session, complete ordered results, disposed handles.
    Evidence: .sisyphus/evidence/task-4-ldap.txt
  Scenario: Insecure/certificate-invalid endpoint fails closed
    Tool: Bash (pwsh/Pester)
    Steps: Fail LDAPS and StartTLS/cert validation with explicit Credential.
    Expected: Connection rejected; no plain bind; redacted error.
    Evidence: .sisyphus/evidence/task-4-ldap-security.txt
  ```
  **Commit**: NO

- [ ] 5. Replace AD connection validation with one-target protocol resolution
  **What to do**:
  - Add `ActiveDirectoryForest`, `ActiveDirectoryDomain`, `ActiveDirectoryServer`, `ActiveDirectoryCredential` to `Connect-Maester` only; keep `Invoke-Maester` unchanged.
  - Resolve RootDSE/Partitions/crossRef via Task 4; forest-only selects root domain, server-only derives domain/forest, combinations validate alignment.
  - Ambient mode is integrated-auth discovery where supported; non-Windows without an explicit endpoint fails with guidance.
  - Store flat non-secret state: Connected/Error, requested/resolved values, naming contexts, server, TLS/auth modes, capability flags, TargetLabel. Clear private credential/caches on failure/disconnect.
  **Must NOT do**: No arrays, target list/map/current key, public switching command, fallback from an invalid explicit target.
  **Agent Profile**: Category `deep`; Skills [] (public API compatibility).
  **Parallelization**: NO | Wave 2 | Blocks 6–15 | Blocked by 4.
  **References**: `powershell/public/Connect-Maester.ps1:133-159,468-494`; `Test-MtConnection.ps1:89-97`; `Disconnect-Maester.ps1:60-65`.
  **Acceptance Criteria**:
  - Pester covers every allowed selector combination and every conflict/misalignment.
  - `-Service All` remains AD-free; explicit failures never fall back; session output is credential-free.
  **QA Scenarios**:
  ```
  Scenario: Selector matrix resolves one target
    Tool: Bash (pwsh/Pester)
    Steps: Test ambient and all seven explicit selector combinations with/without Credential.
    Expected: Same aligned target/TargetLabel; flat state only.
    Evidence: .sisyphus/evidence/task-5-target-matrix.txt
  Scenario: Conflicting selector and failed bind
    Tool: Bash (pwsh/Pester)
    Steps: Pair forest A, domain B, server C and invalid credentials.
    Expected: Connected false, redacted specific error, no fallback/cache.
    Evidence: .sisyphus/evidence/task-5-target-errors.txt
  ```
  **Commit**: NO

- [ ] 6. Implement LDAP query catalog and Maester contract normalizers
  **What to do**:
  - Place query functions under `powershell/internal/ad/queries/`; prefix all with `Get-MtLdap` or `Invoke-MtLdap` and keep them unexported.
  - Add focused internal queries for domain/forest/partitions, users, computers, groups, service accounts, DCs, sites/subnets/connections, trusts, OUs, optional features, configuration/schema/PKI/printers/LAPS, domain attributes, default/FGPP policies, and group members.
  - Convert LDAP syntax and attributes to exact contracts: FILETIME/GeneralizedTime→DateTime, interval→TimeSpan, UAC bits→bools, SID bytes→object exposing `.Value`, GUIDs, enums/scope/category strings, arrays, and null semantics.
  - Implement ranged memoized group membership keyed by target+group DN; resolve foreign security principals without recursive unbounded traversal.
  **Must NOT do**: No public cmdlet shims named `Get-AD*`; no unconstrained property loads.
  **Agent Profile**: Category `deep`; Skills [] (large typed normalization surface).
  **Parallelization**: NO | Wave 3 | Blocks 7,8,12,14 | Blocked by 2,4,5.
  **References**: Task 2 fixtures; `Get-MtADDomainState.ps1:64-76`; direct consumers under `powershell/public/ad/passwordpolicy`, `group`, `domain`.
  **Acceptance Criteria**:
  - All query helpers return Task 2-compatible types from raw LDAP fixtures.
  - Large membership (>1500) range fixture is complete, memoized, bounded, and preserves foreign SID data.
  **QA Scenarios**:
  ```
  Scenario: Raw LDAP becomes Maester objects
    Tool: Bash (pwsh/Pester)
    Steps: Feed representative binary/string/multivalue fixtures through every normalizer.
    Expected: Contract validator passes and no culture-dependent conversion occurs.
    Evidence: .sisyphus/evidence/task-6-normalizers.txt
  Scenario: Large malformed membership is safe
    Tool: Bash (pwsh/Pester)
    Steps: Return multiple ranges plus duplicate/invalid DN values.
    Expected: Complete unique valid members, bounded warnings, second query hits cache.
    Evidence: .sisyphus/evidence/task-6-membership.txt
  ```
  **Commit**: NO

- [ ] 7. Migrate `Get-MtADDomainState` and `Get-MtADDacls` to LDAP
  **What to do**:
  - Replace every `Get-AD*`, ADSI, DirectoryEntry/Searcher operation with Tasks 4/6 queries while preserving all top-level and nested keys/types.
  - Collect password policies, FGPP, domain config attributes, OU gpOptions/gPLink, and memoizable data needed by checks; explicitly include `dNSHostName`.
  - Rebuild DACL entries from protocol security descriptors with current fields/strings; keep `Get-MtADDacls` ACE behavior.
  - Preserve ambient/explicit `ComputerName` precedence where compatible, one-target cache keys, refresh/clear semantics, and per-subsection error metadata.
  **Must NOT do**: No DNS/GPO/SMB implementation in this task; no arbitrary 20-zone truncation.
  **Agent Profile**: Category `deep`; Skills [] (primary collector migration).
  **Parallelization**: YES | Wave 3 | Blocks 14,17 | Blocked by 4–6.
  **References**: `powershell/public/Get-MtADDomainState.ps1:41-497`; `Get-MtADDacls.ps1:42-139`; DACL checks.
  **Acceptance Criteria**:
  - Structural scan finds zero legacy AD/ADSI calls in both collectors.
  - Full contract fixture equals baseline keys/types; ambient/explicit cache and failure tests pass.
  **QA Scenarios**:
  ```
  Scenario: Complete LDAP domain/DACL snapshot
    Tool: Bash (pwsh/Pester fixtures)
    Steps: Run collectors against recorded protocol responses and compare contract manifest.
    Expected: All required keys/types/count semantics match baseline.
    Evidence: .sisyphus/evidence/task-7-domain-dacl.txt
  Scenario: Subsection access failure is isolated
    Tool: Bash (pwsh/Pester)
    Steps: Deny schema/PKI ACL read while core bind/domain succeeds.
    Expected: Core state returned; affected capability/error explicit; unrelated data intact.
    Evidence: .sisyphus/evidence/task-7-partial-error.txt
  ```
  **Commit**: NO

- [ ] 8. Rebuild GPO metadata, links, and permissions from LDAP
  **What to do**:
  - Enumerate `groupPolicyContainer` objects and shape GPOs (`Id`, `DisplayName`, `CreationTime`, `ModificationTime`, `GpoStatus` from flags, `Owner`, `WmiFilter`, versions, file path).
  - Collect domain/OU/site `gPLink`/`gpOptions`; parse links once into `GPOLinks`, `SiteContainers`, disabled/enforced counts.
  - Parse GPC security descriptors for canonical permission booleans and owner; map known SIDs/extended right GUIDs.
  **Must NOT do**: No GroupPolicy cmdlets, SYSVOL reads, or full GPO report XML emulation.
  **Agent Profile**: Category `deep`; Skills [] (LDAP/GPO semantics).
  **Parallelization**: YES | Wave 4 | Blocks 10,14 | Blocked by 2,4–6.
  **References**: `Get-MtADGpoState.ps1:43-204`; GPO/GPOState consumers; MS-GPOL/MS-ADTS specs.
  **Acceptance Criteria**:
  - LDAP fixture produces all canonical GPO metadata/link/permission fields and aliases.
  - Link parser handles multiple links, disabled/enforced flags, malformed entries, domain/OU/site scope.
  **QA Scenarios**:
  ```
  Scenario: GPC and ACL shape canonical GPO state
    Tool: Bash (pwsh/Pester)
    Steps: Feed GPC/link/security descriptor fixtures.
    Expected: Contract passes; owner/status/WMI/permission booleans and links exact.
    Evidence: .sisyphus/evidence/task-8-gpo-ldap.txt
  Scenario: Malformed link/ACL is contained
    Tool: Bash (pwsh/Pester)
    Steps: Include invalid gPLink and truncated descriptor.
    Expected: Per-object error, no crash or false positive permission value.
    Evidence: .sisyphus/evidence/task-8-gpo-errors.txt
  ```
  **Commit**: NO

- [ ] 9. Implement credentialed cross-platform SYSVOL transport and bounded parsers
  **What to do**:
  - Implement the transport entry point as private `powershell/internal/ad/transport/Get-MtSysvolContent.ps1`; hide Windows/Unix branching behind this one function.
  - Windows adapter: temporary credentialed `New-PSDrive`/UNC scope, deterministic removal. Unix adapter: `smbclient` with mode-600 auth file or Kerberos ccache; never password arguments.
  - Use resolved server/domain and same credential identity. Add connect/list/read text/read bytes APIs, path traversal protection, timeouts, max file (10 MiB) and per-GPO total (100 MiB) bounds.
  - Parse `GPT.INI`, relevant GPP XML recursively, `GptTmpl.inf`, and only current-check-required files; detect `cpassword` and default-password patterns safely.
  **Must NOT do**: No mounted persistent share, shell interpolation, retained auth file, or unbounded binary parsing.
  **Agent Profile**: Category `unspecified-high`; Skills [] (cross-platform process/filesystem security).
  **Parallelization**: YES | Wave 4 | Blocks 10 | Blocked by 2,3,5.
  **References**: SYSVOL paths from LDAP `gPCFileSysPath`; `SMBLibrary` research rejected in favor of OS-native clients; current cpassword/default checks.
  **Acceptance Criteria**:
  - Windows/Unix fixture adapters return identical normalized file data.
  - Process list/log/evidence contains no password; temp mappings/files removed on success/error/cancel.
  **QA Scenarios**:
  ```
  Scenario: Credentialed SYSVOL read is cross-platform equivalent
    Tool: Bash (pwsh/Pester fake process/native mapping)
    Steps: Read GPT.INI and GPP XML through Windows and Unix adapters.
    Expected: Same versions/findings; credentials absent from args/output; cleanup verified.
    Evidence: .sisyphus/evidence/task-9-sysvol.txt
  Scenario: Hostile SYSVOL input is bounded
    Tool: Bash (pwsh/Pester)
    Steps: Attempt traversal, oversized file, malformed XML, command metacharacters.
    Expected: Rejected/redacted errors; no out-of-root read or leak.
    Evidence: .sisyphus/evidence/task-9-sysvol-security.txt
  ```
  **Commit**: NO

- [ ] 10. Rebuild `Get-MtADGpoState` from LDAP and SYSVOL
  **What to do**:
  - Compose Tasks 8/9 into existing `GPOs`, `GPOReports`, `GPOLinks`, `SiteContainers`, `CollectionTime` shape.
  - Compare AD version with GPT.INI for mismatch; combine link enforcement/disabled counts, ACL booleans, cpassword/default findings, aliases `Name/GPOName` and `Enforcement/EnforcementEnabled`.
  - Cache by resolved target; record transport-specific per-GPO errors without fabricating booleans.
  **Must NOT do**: No GroupPolicy import/cmdlets or full report XML schema.
  **Agent Profile**: Category `deep`; Skills [] (contract integration).
  **Parallelization**: NO | Wave 4 | Blocks 14,17 | Blocked by 8,9.
  **References**: `Get-MtADGpoState.ps1`; Task 2 canonical schema; all `powershell/public/ad/gpo*` consumers.
  **Acceptance Criteria**:
  - All GPO/GPOState checks run against canonical fixture with no missing property.
  - Structural scan finds zero Get-GPO/Get-GPOReport/DirectoryEntry calls.
  **QA Scenarios**:
  ```
  Scenario: LDAP+SYSVOL reproduces consumed GPO contract
    Tool: Bash (pwsh/Pester)
    Steps: Combine linked GPC, ACL, GPT version, and GPP fixtures; run all GPO checks.
    Expected: Expected counts/details and both compatibility aliases present.
    Evidence: .sisyphus/evidence/task-10-gpo-state.txt
  Scenario: SYSVOL unavailable does not fake findings
    Tool: Bash (pwsh/Pester)
    Steps: LDAP succeeds, SMB fails.
    Expected: Metadata/link checks work; file-derived checks get explicit backend error/skip detail.
    Evidence: .sisyphus/evidence/task-10-gpo-partial.txt
  ```
  **Commit**: NO

- [ ] 11. Implement the credentialed WinRM/PSRP management executor
  **What to do**:
  - Implement private `powershell/internal/ad/transport/Invoke-MtADManagementCommand.ps1` with a fixed ValidateSet of `DnsInventory` and `SmbConfiguration` operations.
  - Add one private remote executor using native WSMan on Windows and PSWSMan on Unix, targeting resolved server with same private Credential; prefer HTTPS/validated cert, otherwise Negotiate with message encryption per documented matrix.
  - Expose bounded DNS-WMI and SMB-config operations only; timeout/cancel/dispose sessions; shape redacted capability/errors.
  - Prevent command injection by fixed scriptblocks and typed arguments; never serialize credentials into scripts/results.
  **Must NOT do**: No generic public remote-command API, Linux-local CIM, credential logging, or TrustedHosts wildcard automation.
  **Agent Profile**: Category `deep`; Skills [] (remote execution/security).
  **Parallelization**: YES | Wave 5 | Blocks 12,13 | Blocked by 3,5.
  **References**: Existing `Invoke-Command` SMB block in `Get-MtADDomainState.ps1:128-144`; PSWSMan docs; `Disconnect-Maester.ps1` cleanup.
  **Acceptance Criteria**:
  - Windows/Unix mocks prove identical typed invocation, timeout, disposal, redaction, and cert/auth failures.
  - No generic script text or password appears in process args/session output.
  **QA Scenarios**:
  ```
  Scenario: Credentialed management operation succeeds
    Tool: Bash (pwsh/Pester mocked PSSession)
    Steps: Open validated session and invoke each allow-listed operation.
    Expected: Typed normalized response; one reused scoped session; cleanup.
    Evidence: .sisyphus/evidence/task-11-psrp.txt
  Scenario: Untrusted endpoint/auth failure closes safely
    Tool: Bash (pwsh/Pester)
    Steps: Fail cert, auth, timeout, and malformed response.
    Expected: Redacted capability error; no fallback/injection/retained session.
    Evidence: .sisyphus/evidence/task-11-psrp-errors.txt
  ```
  **Commit**: NO

- [ ] 12. Replace DnsServer collection with remote MicrosoftDNS WMI normalization
  **What to do**:
  - Through Task 11, query `root\MicrosoftDNS` for AD-integrated and file-backed zones, records, and root hints using Windows PowerShell endpoint/WMI provider—without DnsServer module.
  - Normalize zone types and all record metadata; create typed `RecordData` for A/NS/SRV/SOA; preserve generic record type counts/DNSSEC; map `..RootHints` to `RootDNSServers`; map timestamp zero to null.
  - Remove the first-20-zone limit and bound by configurable timeout/result count with explicit truncation error rather than silent loss.
  **Must NOT do**: No local CIM on Unix, DnsServer cmdlets, or false empty arrays on backend failure.
  **Agent Profile**: Category `deep`; Skills [] (WMI/DNS contract mapping).
  **Parallelization**: YES | Wave 5 | Blocks 17 | Blocked by 2,4–6,11.
  **References**: DNS consumers under `powershell/public/ad/dns`; `MicrosoftDNS_Zone`, record subclasses, `MicrosoftDNS_RootHints` docs.
  **Acceptance Criteria**:
  - All DNS check fixtures pass, including A/NS/SRV/SOA typed fields, dynamic/static timestamps, root hints, reverse/file-backed zones.
  - Product/build scan finds zero Get-DnsServer/import DnsServer.
  **QA Scenarios**:
  ```
  Scenario: WMI DNS state matches Maester contract
    Tool: Bash (pwsh/Pester remote fixtures)
    Steps: Normalize integrated/file zones, root hints, and record subclasses; run all DNS checks.
    Expected: Contract/count/detail assertions pass with no truncation.
    Evidence: .sisyphus/evidence/task-12-dns.txt
  Scenario: DNS backend denied/unavailable
    Tool: Bash (pwsh/Pester)
    Steps: Return access denied and provider missing.
    Expected: DNS capability error and affected checks skip/error explicitly; no false empty-success.
    Evidence: .sisyphus/evidence/task-12-dns-error.txt
  ```
  **Commit**: NO

- [ ] 13. Replace live SMB configuration collection through the management executor
  **What to do**:
  - Resolve every DC from LDAP and invoke allow-listed remote `Get-SmbServerConfiguration` through Task 11 with same credential.
  - Shape only `DCName`, `EnableSMB1Protocol`, `EnableSMB2Protocol`, `EnableSMB3_1_1Protocol`, `EnableSecuritySignature`, `RequireSecuritySignature` as booleans.
  - Aggregate per-DC errors/capabilities without dropping successful DCs.
  **Must NOT do**: No direct public collector `Invoke-Command`, local SmbShare dependency, or registry inference presented as live state.
  **Agent Profile**: Category `unspecified-high`; Skills [] (remote state integration).
  **Parallelization**: YES | Wave 5 | Blocks 17 | Blocked by 5,11.
  **References**: `Get-MtADDomainState.ps1:128-144`; three SMB checks under `powershell/public/ad/domaincontroller`.
  **Acceptance Criteria**:
  - Exact SMB contract passes all three checks for mixed DC fixtures.
  - Partial DC failure is attributed and never changes another DC's booleans.
  **QA Scenarios**:
  ```
  Scenario: Multi-DC live SMB state is shaped
    Tool: Bash (pwsh/Pester)
    Steps: Return differing settings for three DCs and run SMB checks.
    Expected: Correct per-DC counts/details and booleans.
    Evidence: .sisyphus/evidence/task-13-smb.txt
  Scenario: One DC remoting fails
    Tool: Bash (pwsh/Pester)
    Steps: Fail second DC only.
    Expected: Two results retained; explicit second-DC backend error; no fabricated config.
    Evidence: .sisyphus/evidence/task-13-smb-error.txt
  ```
  **Commit**: NO

- [ ] 14. Remove every direct legacy AD/GPO/DNS call from analysis functions
  **What to do**:
  - Replace ~32 follow-on `Get-AD*` calls with enhanced collector state or focused internal LDAP helpers: password policy/FGPP/domain attrs/tombstone/OU links from state; ranged group membership via Task 6.
  - Update GPO/DNS checks only for canonical aliases/error metadata, preserving thresholds, titles, and result semantics.
  - Rewrite AST opt-in guard to require guarded collectors/internal protocol helpers and ban removed module commands/ADSI.
  **Must NOT do**: No public compatibility shims named like legacy cmdlets, broad business-logic refactor, or changed findings.
  **Agent Profile**: Category `deep`; Skills [] (broad semantic-preserving migration).
  **Parallelization**: NO | Wave 6 | Blocks 17 | Blocked by 5–8,10.
  **References**: `ActiveDirectoryOptIn.Tests.ps1:165-260`; 29 affected files in domain/passwordpolicy/group/gpo.
  **Acceptance Criteria**:
  - Structural scan has zero `Get-AD*|Get-GPO*|Get-DnsServer*|DirectoryEntry|DirectorySearcher` in product/test commands.
  - Every affected check returns baseline result for contract fixtures.
  **QA Scenarios**:
  ```
  Scenario: All follow-on categories preserve outcomes
    Tool: Bash (pwsh/Pester)
    Steps: Run domain/password/group/GPO/DNS check suites against before/after fixtures.
    Expected: Same booleans/counts/details; zero banned AST calls.
    Evidence: .sisyphus/evidence/task-14-analysis.txt
  Scenario: Collector/backend error propagates honestly
    Tool: Bash (pwsh/Pester)
    Steps: Inject group range and password-policy query failures.
    Expected: Affected check records explicit error/skip; no false pass/fail.
    Evidence: .sisyphus/evidence/task-14-errors.txt
  ```
  **Commit**: NO

- [ ] 15. Add target provenance and separate-run merge support without changing `Invoke-Maester`
  **What to do**:
  - Populate optional `TargetLabel`, resolved forest/domain/server and fallback AD `TenantName/TenantId` in `ConvertTo-MtMaesterResult` when Graph is absent; never include credentials.
  - Preserve fields through import/merge/JSON/Markdown/HTML/report model; distinguish same-forest root/child and second-forest runs.
  - Document/run separate `Connect`+`Invoke` processes and merge artifacts with `Merge-MtMaesterResult`; no target loop.
  **Must NOT do**: No Invoke-Maester orchestration, target registry, or overwrite of Graph tenant identity.
  **Agent Profile**: Category `deep`; Skills [] (result compatibility).
  **Parallelization**: YES | Wave 6 | Blocks 17,19,20 | Blocked by 5.
  **References**: `ConvertTo-MtMaesterResult.ps1`; `Merge-MtMaesterResult.ps1`; report result types.
  **Acceptance Criteria**:
  - Two same-forest and one second-forest fixture merge retain three unique labels and all tests.
  - Graph-connected runs preserve original tenant identity plus optional AD target provenance.
  **QA Scenarios**:
  ```
  Scenario: Three AD runs merge distinctly
    Tool: Bash (pwsh/Pester)
    Steps: Import/merge root, child, second-forest JSON fixtures.
    Expected: Three target labels, no overwritten tests, renderers include provenance.
    Evidence: .sisyphus/evidence/task-15-merge.txt
  Scenario: Credential never enters result
    Tool: Bash (pwsh/secret scan)
    Steps: Execute conversion with sentinel credential and scan all formats.
    Expected: Zero sentinel/username/password/SecureString serialization.
    Evidence: .sisyphus/evidence/task-15-result-security.txt
  ```
  **Commit**: NO

- [ ] 16. Replace legacy runners and publish complete targeting/prerequisite documentation
  **What to do**:
  - Update/retire every `build/activeDirectory` script that imports/tests ActiveDirectory/GroupPolicy/DnsServer; add protocol prerequisite and isolated-run scripts.
  - Create `website/docs/monitoring/active-directory.md` with selector matrix, forest-root semantics, ambient limitations, credentials/TLS/cert trust, PSWSMan/WinRM, Windows SMB/Unix smbclient, examples for all combinations, errors, separate-run merge, and least privilege.
  - Rewrite `docs/e2e-ad-testing-guide.md` for local build and five-VM lab; update source help and regenerate command docs via automation.
  - Update blog/prerequisite source references that claim removed modules are required.
  **Must NOT do**: No generated website command/test/versioned-doc hand edits, sample plaintext passwords, or unsupported platform claims.
  **Agent Profile**: Category `writing`; Skills [] (docs/runbooks/scripts).
  **Parallelization**: YES | Wave 6 | Blocks 17–20 | Blocked by 3,15.
  **References**: `build/activeDirectory/Run-ADTests-And-CopyReports.ps1`; `README-ADTestRunner.md`; `website/blog/2026-04-25-active-directory-security-testing/index.md`; docs generation commands.
  **Acceptance Criteria**:
  - Repo docs/build scan has zero claims/imports requiring removed modules.
  - Every allowed selector combination has a copyable command and expected target semantics; unsupported/misaligned examples show exact errors.
  **QA Scenarios**:
  ```
  Scenario: Documentation matrix is complete
    Tool: Bash (docs test/grep)
    Steps: Validate each selector row/example/prerequisite/merge command and links.
    Expected: All combinations represented; no removed command/module requirement.
    Evidence: .sisyphus/evidence/task-16-docs.txt
  Scenario: Runner preflight is safe
    Tool: Bash (pwsh dry run)
    Steps: Run protocol preflight with missing TLS/PSWSMan/smbclient/WinRM cases.
    Expected: Actionable redacted failures and no mutation/credential leak.
    Evidence: .sisyphus/evidence/task-16-preflight.txt
  ```
  **Commit**: NO

- [ ] 17. Run complete structural, unit, platform, build, and secret validation
  **What to do**:
  - Run changed-file parsers/PSScriptAnalyzer, all focused protocol/contract/AD suites, canonical `powershell/tests/pester.ps1`, module build/output validation, docs build, and package import on PS5.1/PS7.
  - Enforce zero removed module imports/calls across `powershell/public`, `tests/ad`, and retained `build/activeDirectory`; whitelist only intentional internal remote `Get-SmbServerConfiguration` scriptblock.
  - Scan source, logs, fixtures, results, process captures, and temp directories for credential sentinels.
  **Must NOT do**: Do not waive analyzer/help failures or count mocked success as live E2E.
  **Agent Profile**: Category `deep`; Skills [] (full validation).
  **Parallelization**: NO | Wave 7 | Blocks 18,19 | Blocked by 7,10,12–16.
  **References**: `powershell/tests/pester.ps1`; `build/Build-MaesterModule.ps1`; `build/Test-MaesterModuleOutput.ps1`; `website/package.json`.
  **Acceptance Criteria**:
  - All commands exit 0; zero banned dependency matches; package imports without removed modules.
  - Secret scans and temp/mapping/session cleanup assertions pass.
  **QA Scenarios**:
  ```
  Scenario: Full local matrix passes
    Tool: Bash (powershell/pwsh/npm)
    Steps: Run focused/full tests, builds, package imports, docs build on available matrices.
    Expected: Zero failures/analyzer warnings/banned calls.
    Evidence: .sisyphus/evidence/task-17-validation.txt
  Scenario: Sentinel credential cannot escape
    Tool: Bash (secret/process/temp scan)
    Steps: Run all adapters with unique sentinel through success/failure.
    Expected: Sentinel absent outside private in-memory test hook; no temp/session/mapping remains.
    Evidence: .sisyphus/evidence/task-17-secrets.txt
  ```
  **Commit**: NO

- [ ] 18. Deploy the Azure multi-platform, multi-forest E2E lab
  **What to do**:
  - In `RG_5100_MiSoule_2`/`eastus`, deploy tagged VNet `MiSouleADTestVNet` (`10.20.0.0/24`) and: `MiSouleDC02` root `misoule02.local` `.4`; `MiSouleDC03` child `child.misoule02.local` `.5`; `MiSouleDC04` forest `misoule03.local` `.6`; Windows runner `MiSouleRunnerWin` `.10`; Ubuntu runner `MiSouleRunnerLinux` `.11`.
  - Configure DNS sequencing, LDAPS/StartTLS certs trusted by runners, WinRM HTTPS/Negotiate endpoints, domain test credentials with required read/WMI/remoting rights, native SMB/smbclient, PSWSMan, and local module build.
  - Ensure runners lack ActiveDirectory, GroupPolicy, DnsServer modules; Windows runner validates PS5.1 and PS7, Ubuntu validates PS7.
  - Restrict NSGs to executor IP and lab subnet; use generated ephemeral credentials, tags, collision/cost guards, and automatic failure cleanup.
  **Must NOT do**: No RDP exposure, public secret, gallery patch, unrelated resource reuse, or untagged orphan.
  **Agent Profile**: Category `unspecified-high`; Skills [] (Azure/Windows/Linux infrastructure).
  **Parallelization**: NO | Wave 8 | Blocks 19,20 | Blocked by 16,17.
  **References**: corrected `docs/e2e-ad-testing-guide.md`; existing guide promotion/SSH patterns; Task 16 scripts.
  **Acceptance Criteria**:
  - Five hosts healthy; domain topology/certs/WinRM/SMB/PSWSMan verified; removed modules absent on runners.
  - Non-secret topology/capability evidence recorded; failure cleanup test leaves zero failed-run resources.
  **QA Scenarios**:
  ```
  Scenario: Lab satisfies transport matrix
    Tool: Bash (az/ssh/pwsh/powershell)
    Steps: Verify hosts, domains, TLS chains, LDAP, WinRM, SYSVOL, prerequisites, absent modules.
    Expected: Every prerequisite succeeds on both runners for intended targets.
    Evidence: .sisyphus/evidence/task-18-topology.json
  Scenario: Deployment failure is cost-safe
    Tool: Bash (az)
    Steps: Trigger dry-run/controlled health failure and teardown by tag.
    Expected: Nonzero failure and zero tagged/orphaned resources.
    Evidence: .sisyphus/evidence/task-18-failure-cleanup.txt
  ```
  **Commit**: NO

- [ ] 19. Execute Windows PS5.1/PS7 and Ubuntu PS7 live target runs
  **What to do**:
  - Fresh process per run. Windows integrated ambient/root and explicit credential runs; Ubuntu explicit credential runs.
  - Cover root forest-only, child Domain+Server, second Forest+Domain+Server, Server-only, and representative aligned combinations. Run collectors and full AD suite, emit JSON/Markdown/HTML.
  - Assert LDAP shapes, GPO/SYSVOL, file-backed/integrated DNS/root hints, live SMB, errors/capabilities, TargetLabel, and absent removed modules.
  **Must NOT do**: No process/cache reuse across targets, module install, manual report inspection, or silent skipped backend.
  **Agent Profile**: Category `unspecified-high`; Skills [] (live cross-platform QA).
  **Parallelization**: YES | Wave 8 | Blocks 20 | Blocked by 15–18.
  **References**: Task 16 targeting guide/run scripts; Task 2 contracts.
  **Acceptance Criteria**:
  - Each run exits 0 with `TotalCount > 0`; contract probes and three report formats pass.
  - Explicit invalid credential/TLS/misaligned selector runs fail closed with redacted errors.
  **QA Scenarios**:
  ```
  Scenario: Live platform/target matrix succeeds
    Tool: Bash (ssh/powershell/pwsh)
    Steps: Run isolated matrix and collect machine-readable summaries/artifacts.
    Expected: All expected success rows pass with exact TargetLabel and data contracts.
    Evidence: .sisyphus/evidence/task-19-live-matrix.json
  Scenario: Live security failures are closed/redacted
    Tool: Bash (ssh/pwsh)
    Steps: Test bad cert, bad credential, conflicting selectors, unavailable WinRM/SYSVOL.
    Expected: Correct scoped failures; no fallback, false pass, or secret leakage.
    Evidence: .sisyphus/evidence/task-19-live-errors.txt
  ```
  **Commit**: NO

- [ ] 20. Merge target results, prove documentation workflows, and tear down completely
  **What to do**:
  - Execute every documented selector example against fixtures/live applicable target; merge root/child/second-forest results and validate unique provenance/rendering.
  - Produce final Maester-vs-Locksmith2 comparison (protocols, targeting, credentials, shapes, tests; no dependency).
  - Delete all tagged Azure compute/network/storage/public IP resources, remote/local auth files, credentials, sessions, mappings, cert private keys, and temp artifacts; poll to zero.
  - Rerun final structural scan, full tests/build, diff check, and secret scan.
  **Must NOT do**: No retained billable resources, credential-bearing evidence, commit/push, or completion before F1–F4/user approval.
  **Agent Profile**: Category `unspecified-high`; Skills [`git-master`] for final status/diff only.
  **Parallelization**: NO | Wave 9 | Blocks Final verification | Blocked by 18,19.
  **References**: `Merge-MtMaesterResult.ps1`; Task 16 docs; Azure teardown scripts.
  **Acceptance Criteria**:
  - Merged output has three unique target labels and all source tests; documented examples pass.
  - Azure tag query returns zero; no secrets/temp sessions/mappings; full local validation passes.
  **QA Scenarios**:
  ```
  Scenario: Documented multi-target merge is reproducible
    Tool: Bash (pwsh)
    Steps: Run documented merge on three live artifacts and validate JSON/Markdown/HTML provenance/counts.
    Expected: Three distinguishable targets; no overwrite; render succeeds.
    Evidence: .sisyphus/evidence/task-20-merge.json
  Scenario: Cleanup and final verification are complete
    Tool: Bash (az/git/pwsh/secret scan)
    Steps: Teardown/poll; scan temp/source/evidence; run tests/build/diff.
    Expected: Zero resources/secrets/failures; only intended changes remain.
    Evidence: .sisyphus/evidence/task-20-final.txt
  ```
  **Commit**: NO

## Final Verification Wave
> F1–F4 run in parallel after Task 20. All must approve; present results and wait for explicit user approval.

- [ ] F1. Plan Compliance Audit — oracle
  - Tool: `task(subagent_type="oracle")` with plan, final diff, and evidence manifest.
  - Steps: Check every acceptance criterion and verify all removed dependencies/registry architecture are absent.
  - Expected: `APPROVE` with zero unmet criteria.
  - Evidence: `.sisyphus/evidence/final-f1-compliance.txt`
- [ ] F2. Code Quality and Security Review — unspecified-high
  - Tool: `task(category="unspecified-high")` with diff and test/security outputs.
  - Steps: Review protocol security, credential lifetime, parser bounds, disposal, cross-platform packaging, errors, and compatibility.
  - Expected: `APPROVE` with no correctness/security/analyzer blocker.
  - Evidence: `.sisyphus/evidence/final-f2-quality-security.txt`
- [ ] F3. Real Cross-Platform QA — unspecified-high
  - Tool: `task(category="unspecified-high")` using Bash, PowerShell, Azure CLI, and SSH.
  - Steps: Re-run representative Windows/Ubuntu live success/failure rows, merge, artifact checks, and zero-resource query.
  - Expected: Binary pass; intentional failures closed/redacted; cleanup zero.
  - Evidence: `.sisyphus/evidence/final-f3-qa.txt`
- [ ] F4. Scope Fidelity Review — deep
  - Tool: `task(category="deep")` with original request, PR #2002, plan, and final diff.
  - Steps: Compare final diff to objectives and reject unrelated core changes, target registries, or incomplete module removal.
  - Expected: `APPROVE` confirming minimal core changes and complete protocol migration.
  - Evidence: `.sisyphus/evidence/final-f4-scope.txt`

## Commit Strategy
- Work only on `ad-multiforest-targeting`, never on `main`.
- Do not commit unless separately requested.
- If later requested, split contracts/transport, LDAP collectors, GPO/SYSVOL, management backend, analysis migration, and docs/E2E into atomic commits with tests.

## Success Criteria
- The three removed modules are unnecessary on every supported execution path.
- Targeting/credential combinations are deterministic, validated, and documented.
- Existing AD checks receive compatible data without core runner orchestration changes.
- Live Windows/Ubuntu and merged multi-target evidence pass with no secret leakage.

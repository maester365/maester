# Plan 2: LDAP Collectors & Analysis Migration

> **Reference View** — This is a segmented summary of the master plan `ad-integration-protocol-targeting.md` (Tasks 6–8, 14). For execution, always use the master plan which contains full QA scenarios, agent profiles, and dependency matrices.

## TL;DR
> **Scope**: Query catalog, contract normalizers, domain/DACL/GPO-metadata collectors, and removal of all legacy `Get-AD*` calls from analysis functions. Everything that reads directory state via LDAP.
> **Deliverables**: Query catalog, normalizers, `Get-MtADDomainState`, `Get-MtADDacls`, GPO metadata from LDAP, clean analysis functions.
> **Effort**: XL
> **Parallel**: YES — 3 waves
> **Critical Path**: 6 → 7 → 8 → 14
> **Prerequisite**: Plan 1 (AD Protocol Foundation) complete. Plan 4 Task 20b (E2E Re-Validation) must run after Plans 1–3 are complete under the Plan 9 three-track mandatory validation process.

## Context
This plan implements all directory-state collection via LDAP and migrates every analysis function away from `Get-AD*` / `DirectoryEntry` / `DirectorySearcher`. It does NOT touch SYSVOL, WinRM/PSRP, DNS WMI, or SMB remoting—those are in Plan 3.

### E2E Validation Alignment (Plan 9)
All LDAP collectors and analysis functions in this plan are certified through the Plan 9 three-track mandatory validation process: hard preflight gate (`Test-LabPrerequisites.ps1`), protocol probe matrix (`Invoke-ProtocolProbeMatrix.ps1`), and public E2E runner matrix (`Invoke-PublicE2EMatrix.ps1`). The canonical lab topology is: `MiSouleDC02/misoule02.local`, `MiSouleDC03/child.misoule02.local`, `MiSouleDC04/misoule03.local`, `MiSouleRunnerWin`, `MiSouleRunnerLinux`. Every mandatory E2E row must emit machine-readable identity/auth/TLS artifacts plus JSON/Markdown/HTML Maester reports. Plan 9 Task 10 (full re-validation cycle) replaces the old Plan 1 "could not be validated" table with definitive pass/fail outcomes for every row.

## Wave 1: Query Catalog & Normalizers (Task 6)

### Task 6 — Implement LDAP query catalog and Maester contract normalizers
**What to do**:
- Place query functions under `powershell/internal/ad/queries/`; prefix all with `Get-MtLdap` or `Invoke-MtLdap` and keep them unexported.
- Add focused internal queries for domain/forest/partitions, users, computers, groups, service accounts, DCs, sites/subnets/connections, trusts, OUs, optional features, configuration/schema/PKI/printers/LAPS, domain attributes, default/FGPP policies, and group members.
- Convert LDAP syntax and attributes to exact contracts: FILETIME/GeneralizedTime→DateTime, interval→TimeSpan, UAC bits→bools, SID bytes→object exposing `.Value`, GUIDs, enums/scope/category strings, arrays, and null semantics.
- Implement ranged memoized group membership keyed by target+group DN; resolve foreign security principals without recursive unbounded traversal.

**Must NOT do**: No public cmdlet shims named `Get-AD*`; no unconstrained property loads.

**Acceptance Criteria**:
- All query helpers return Plan-1-compatible types from raw LDAP fixtures.
- Large membership (>1500) range fixture is complete, memoized, bounded, and preserves foreign SID data.

**References**: Plan 1 fixtures; `Get-MtADDomainState.ps1:64-76`; direct consumers under `powershell/public/ad/passwordpolicy`, `group`, `domain`.

## Wave 2: Collector Migration (Tasks 7–8)

### Task 7 — Migrate `Get-MtADDomainState` and `Get-MtADDacls` to LDAP
**What to do**:
- Replace every `Get-AD*`, ADSI, DirectoryEntry/Searcher operation with Tasks 4/6 queries while preserving all top-level and nested keys/types.
- Collect password policies, FGPP, domain config attributes, OU gpOptions/gPLink, and memoizable data needed by checks; explicitly include `dNSHostName`.
- Rebuild DACL entries from protocol security descriptors with current fields/strings; keep `Get-MtADDacls` ACE behavior.
- Preserve ambient/explicit `ComputerName` precedence where compatible, one-target cache keys, refresh/clear semantics, and per-subsection error metadata.

**Must NOT do**: No DNS/GPO/SMB implementation in this task; no arbitrary 20-zone truncation.

**Acceptance Criteria**:
- Structural scan finds zero legacy AD/ADSI calls in both collectors.
- Full contract fixture equals baseline keys/types; ambient/explicit cache and failure tests pass.

**References**: `powershell/public/Get-MtADDomainState.ps1:41-497`; `Get-MtADDacls.ps1:42-139`; DACL checks.

---

### Task 8 — Rebuild GPO metadata, links, and permissions from LDAP
**What to do**:
- Enumerate `groupPolicyContainer` objects and shape GPOs (`Id`, `DisplayName`, `CreationTime`, `ModificationTime`, `GpoStatus` from flags, `Owner`, `WmiFilter`, versions, file path).
- Collect domain/OU/site `gPLink`/`gpOptions`; parse links once into `GPOLinks`, `SiteContainers`, disabled/enforced counts.
- Parse GPC security descriptors for canonical permission booleans and owner; map known SIDs/extended right GUIDs.

**Must NOT do**: No GroupPolicy cmdlets, SYSVOL reads, or full GPO report XML emulation.

**Acceptance Criteria**:
- LDAP fixture produces all canonical GPO metadata/link/permission fields and aliases.
- Link parser handles multiple links, disabled/enforced flags, malformed entries, domain/OU/site scope.

**References**: `Get-MtADGpoState.ps1:43-204`; GPO/GPOState consumers; MS-GPOL/MS-ADTS specs.

## Wave 3: Analysis Cleanup (Task 14)

### Task 14 — Remove every direct legacy AD/GPO/DNS call from analysis functions
**What to do**:
- Replace ~32 follow-on `Get-AD*` calls with enhanced collector state or focused internal LDAP helpers: password policy/FGPP/domain attrs/tombstone/OU links from state; ranged group membership via Task 6.
- Update GPO/DNS checks only for canonical aliases/error metadata, preserving thresholds, titles, and result semantics.
- Rewrite AST opt-in guard to require guarded collectors/internal protocol helpers and ban removed module commands/ADSI.

**Must NOT do**: No public compatibility shims named like legacy cmdlets, broad business-logic refactor, or changed findings.

**Acceptance Criteria**:
- Structural scan has zero `Get-AD*|Get-GPO*|Get-DnsServer*|DirectoryEntry|DirectorySearcher` in product/test commands.
- Every affected check returns baseline result for contract fixtures.

**References**: `ActiveDirectoryOptIn.Tests.ps1:165-260`; 29 affected files in domain/passwordpolicy/group/gpo.

## Success Criteria
- [x] All directory-state queries live in `powershell/internal/ad/queries/` with correct types.
- [x] `Get-MtADDomainState` and `Get-MtADDacls` contain zero legacy AD/ADSI calls.
- [x] GPO metadata/links/permissions are produced from LDAP alone with canonical aliases.
- [x] All analysis functions pass baseline fixture tests with zero banned AST calls.
- [x] No credential material in logs, cache keys, or results.
- [x] Plan 9 E2E validation passes after Plans 1–3 complete: preflight exits 0, every mandatory protocol probe and public E2E row completes with machine-readable evidence, runners confirm zero legacy module imports, and report formats remain structurally equivalent to baseline. (Cross-plan dependency — validated under Plan 9)

## Commit Strategy
- Work only on `ad-multiforest-targeting`.
- Do not commit unless separately requested.
- If requested later, split into: query catalog, normalizers, domain/DACL migration, GPO metadata, analysis cleanup.

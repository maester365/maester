# Plan 1: AD Protocol Foundation

> **Reference View** — This is a segmented summary of the master plan `ad-integration-protocol-targeting.md` (Tasks 1–5). For execution, always use the master plan which contains full QA scenarios, agent profiles, and dependency matrices.

## TL;DR
> **Scope**: Branch alignment, contract fixtures, packaging, secure LDAP transport, and single-target resolution. Everything needed before any collector can speak to AD without the ActiveDirectory module.
> **Deliverables**: Clean branch, frozen object contracts, protocol packaging, LDAP adapter, target resolver.
> **Effort**: L–XL
> **Parallel**: YES — 3 waves
> **Critical Path**: 1 → 2 → 3 → 4 → 5

## Context
This is the foundation for all subsequent AD protocol work. It establishes the branch, freezes data contracts so consumers don't drift, packages prerequisites for cross-platform LDAP, implements the core LDAP adapter, and wires targeting into `Connect-Maester` without any public switching command or registry.

## Wave 1: Branch & Contracts (Tasks 1–2)

### Task 1 — Align branch and remove rejected target-registry experiment
**What to do**:
- Re-verify `main`/`upstream/main`, rename branch to `ad-multiforest-targeting`, preserve all tracked/untracked work.
- Restore product source to `main` baseline plus merged PR #2002 behavior.
- Remove `Set-MtADTarget`, `ActiveDirectoryTargeting.ps1`, target maps/lists/current keys, and their exports/tests.
- Preserve `docs/e2e-ad-testing-guide.md` and any sibling plans. Record baseline diff before transport changes.

**Must NOT do**: Do not checkout/edit `main`, hard reset, push, or discard user files.

**Acceptance Criteria**:
- `git branch --show-current` is `ad-multiforest-targeting`; `main` is an ancestor.
- Product scan returns zero `Set-MtADTarget|TargetMap|CurrentTargetKey`; PR #2002 `Get-MtADDomainState -ComputerName`/Configuration behavior remains.

**References**: `powershell/public/Set-MtADTarget.ps1`; `powershell/internal/ActiveDirectoryTargeting.ps1`; `powershell/Maester.psd1:58-70`; PR `https://github.com/maester365/maester/pull/2002`.

---

### Task 2 — Freeze target, transport, and object-shape contracts as executable fixtures
**What to do**:
- Add synthetic fixtures/contracts for Domain, Forest, RootDSE, users, computers (including `dNSHostName`), groups/SID.Value, DCs, trusts, password policies/TimeSpan, FGPP, configuration/schema, DACLs, GPOs/reports/links, DNS, and SMB.
- Canonicalize GPO reports as a compatibility superset: `Name`, `GPOName`, `DisabledLinks`, `Enforcement`, `EnforcementEnabled`, `HasVersionMismatch`, `CpasswordFound`, `DefaultPasswordFound`, `PermissionsPresent`, `HasAuthenticatedUsers`, `HasDomainComputers`, `HasEnterpriseDomainControllers`, `HasInheritedPermissions`, `HasApplyGroupPolicyAce`, `HasDenyAce`.
- Define selector matrix and resolution: ambient; Forest(root domain); Domain; Server; all aligned combinations; optional Credential. Reject conflicting values and arrays.
- Define session metadata: resolved forest/domain/server, TLS/auth modes, capability flags. Keep all metadata secret-free.

**Must NOT do**: Do not alter check thresholds/results while freezing schemas.

**Acceptance Criteria**:
- Fixture contract tests enumerate every property/type consumed by shipped AD checks.
- GPO producer/consumer mismatches are represented by both aliases; DNS typed A/NS/SRV/SOA and SMB booleans are fixed.

**References**: `powershell/public/Get-MtADDomainState.ps1`; `Get-MtADGpoState.ps1`; `powershell/public/ad/**`; `powershell/tests/functions/ActiveDirectoryOptIn.Tests.ps1`.

## Wave 2: Packaging & LDAP Transport (Tasks 3–4)

### Task 3 — Define and package protocol prerequisites without legacy modules
**What to do**:
- Establish exact private layout: `powershell/internal/ad/protocol/` (LDAP), `powershell/internal/ad/queries/` (directory query catalog), `powershell/internal/ad/transport/` (SYSVOL/PSRP), and fixtures under `powershell/tests/fixtures/ActiveDirectory/`.
- Verify/load `System.DirectoryServices.Protocols` on Windows PS5.1 and PS7 Windows/Ubuntu; package only assemblies not guaranteed by supported runtimes.
- Add prerequisite detection for PSWSMan/WSMan on Unix and `smbclient`; Windows uses native WinRM and credentialed `New-PSDrive`/UNC.
- Update build/module output to include protocol assets/fixtures but no ActiveDirectory, GroupPolicy, or DnsServer requirement.
- Define version floors, supported auth matrix, and actionable prerequisite errors.

**Must NOT do**: No auto-install during module import, unreviewed binary vendoring, or LGPL/GPL runtime dependency.

**Acceptance Criteria**:
- Build succeeds on Windows PS5.1 and PS7 with no legacy modules installed.
- Unix prerequisite checker reports exact missing PSWSMan/smbclient actions without mutating host.

**References**: `powershell/Maester.psd1:18,36`; `build/Build-MaesterModule.ps1`; PSWSMan docs; .NET `LdapConnection` docs.

---

### Task 4 — Implement the secure LDAP protocol adapter
**What to do**:
- Implement private functions in `powershell/internal/ad/protocol/`: `New-MtLdapConnection`, `Get-MtLdapRootDse`, `Invoke-MtLdapSearch`, `Get-MtLdapRangedValue`, `ConvertFrom-MtLdapValue`, and `ConvertFrom-MtLdapSecurityDescriptor` (one function per file).
- Add private `LdapConnection` factory, RootDSE read, base/one-level/subtree search, paged search, ranged attribute retrieval, DN-safe filter escaping, controls, timeout/cancellation, and deterministic disposal.
- Explicit Credential path: try validated LDAPS 636, then validated StartTLS 389; fail closed if neither is secure. Integrated auth uses Negotiate where supported.
- Request `nTSecurityDescriptor` with appropriate controls and parse via `RawSecurityDescriptor` into existing ACE strings/types.
- Never store credentials in connection metadata/cache; keep only a private in-memory reference cleared on disconnect/module reset.

**Must NOT do**: No Basic bind without TLS, certificate bypass, ADSI/DirectoryEntry/Searcher, or raw credential logging.

**Acceptance Criteria**:
- Unit fixtures prove paging cookie reuse, range completion, escaping, TLS/cert failure, timeout, and disposal.
- Secret scan of verbose/errors/cache/results finds no credential material.

**References**: .NET `LdapConnection`, `StartTransportLayerSecurity`, `PageResultRequestControl`; MS-ADTS paging; Locksmith2 searcher design at commit `ac2476...` (concept only).

## Wave 3: Target Resolution (Task 5)

### Task 5 — Replace AD connection validation with one-target protocol resolution
**What to do**:
- Add `ActiveDirectoryForest`, `ActiveDirectoryDomain`, `ActiveDirectoryServer`, `ActiveDirectoryCredential` to `Connect-Maester` only; keep `Invoke-Maester` unchanged.
- Resolve RootDSE/Partitions/crossRef via Task 4; forest-only selects root domain, server-only derives domain/forest, combinations validate alignment.
- Ambient mode is integrated-auth discovery where supported; non-Windows without an explicit endpoint fails with guidance.
- Store flat non-secret state: Connected/Error, requested/resolved values, naming contexts, server, TLS/auth modes, capability flags. Clear private credential/caches on failure/disconnect.

**Must NOT do**: No arrays, target list/map/current key, public switching command, fallback from an invalid explicit target.

**Acceptance Criteria**:
- Pester covers every allowed selector combination and every conflict/misalignment.
- `-Service All` remains AD-free; explicit failures never fall back; session output is credential-free.

**References**: `powershell/public/Connect-Maester.ps1:133-159,468-494`; `Test-MtConnection.ps1:89-97`; `Disconnect-Maester.ps1:60-65`.

## Success Criteria
- [ ] Branch is clean and `main` is an ancestor; rejected registry removed.
- [ ] Contract fixtures exist and validate every property/type used by AD checks.
- [ ] Module builds on Windows PS5.1/PS7 and Ubuntu PS7 without ActiveDirectory/GroupPolicy/DnsServer.
- [ ] LDAP adapter supports paged/ranged/secure binds with no credential leakage.
- [ ] Target resolver validates all selector combinations and rejects conflicts with flat state only.

## Commit Strategy
- Work only on `ad-multiforest-targeting`.
- Do not commit unless separately requested.
- If requested later, split into: branch/scope reset, contracts, packaging, LDAP transport, targeting.

## Downstream Dependency Note
Plan 4 (Integration & E2E) contains a **Task 20b — Re-Validation** that must run after Plans 1–3 are complete. The E2E lab infrastructure and baseline evidence already exist on the branch, but the final certification of the protocol-migrated code cannot occur until this plan delivers zero legacy module calls.

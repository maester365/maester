# Plan 2: LDAP Collectors & Analysis - Exploration Findings

## 2026-09-22T18:53:00 - Initial Codebase Exploration

### Existing LDAP Protocol Infrastructure
Located under `powershell/internal/ad/protocol/`:
- `Get-MtLdapRootDse.ps1` - Root DSE queries
- `New-MtLdapConnection.ps1` - LDAP connection establishment
- `Invoke-MtLdapSearch.ps1` - Generic LDAP search execution
- `Get-MtLdapRangedValue.ps1` - Ranged attribute retrieval
- `ConvertFrom-MtLdapValue.ps1` - LDAP value normalization
- `ConvertFrom-MtLdapSecurityDescriptor.ps1` - Security descriptor parsing
- `Get-MtAdLdapQueryCatalog.ps1` - Query catalog (exists but may be minimal)
- `Get-MtAdSupportedAuthMatrix.ps1` - Auth method matrix

**NO `powershell/internal/ad/queries/` directory exists yet.**

### Current Collector State

#### Get-MtADDomainState.ps1
- Uses BOTH modern LDAP (Get-MtLdapRootDse, New-MtLdapConnection) AND legacy RSAT Get-AD* cmdlets
- Legacy calls: Get-ADDomain, Get-ADForest, Get-ADComputer, Get-ADUser, Get-ADGroup, Get-ADServiceAccount, Get-ADDomainController, Get-ADReplicationSite, Get-ADReplicationSubnet, Get-ADRootDSE, Get-ADOptionalFeature, Get-ADReplicationConnection, Get-ADObject, Get-ADTrust, Get-ADOrganizationalUnit
- DACL collection uses DirectorySearcher/ADSI path
- Dual-path approach: Protocol-certified LDAP path + Legacy RSAT enrichment path

#### Get-MtADDacls.ps1
- Uses ADSI/DirectoryServices.DirectorySearcher for DACL enumeration
- Loads properties: displayname, distinguishedname, name, ntsecuritydescriptor, objectclass, objectsid
- Clear ADSI-based DOM traversal pattern

#### Get-MtADGpoState.ps1
- Uses Get-GPO -All (GroupPolicy module)
- Uses Get-ADDomain, Get-ADOrganizationalUnit, Get-ADObject
- Uses ADSI for site container queries (LDAP:// sites)
- Caches in $__MtSession.ADCache under 'GpoState'
- Collects: GPOs, CollectionTime, GPOReports, GPOLinks, SiteContainers

### Analysis Functions Using Legacy Cmdlets
~29 affected files across:
- `powershell/public/ad/domain/` - Domain-level checks
- `powershell/public/ad/passwordpolicy/` - Password policy checks
- `powershell/public/ad/group/` - Group checks
- `powershell/public/ad/gpo/` - GPO checks
- `powershell/public/ad/gpostate/` - GPO state checks
- `powershell/public/ad/security/` - Security checks

### Test Infrastructure
- `powershell/tests/functions/ActiveDirectoryOptIn.Tests.ps1` - AST guard/opt-in tests
- `tests/ad/` - ~100 AD test files across subdirectories
- AST guard requires:
  - All AD tests in Describe blocks with -Tag 'AD'
  - Guarded collector calls before AD operations
  - Explicit AD connection before running
  - Documentation includes explicit connection examples
- BeforeAll creates stubs for Get-ADDomain, Get-ADRootDSE, Get-GPO
- ADCache fixture: DomainState, Dacls, GpoState

### Key Migration Patterns Needed
1. FILETIME/GeneralizedTime → DateTime
2. Interval strings → TimeSpan
3. UAC bits → Boolean flags
4. SID bytes → Object with .Value property
5. GUID bytes → Guid object
6. Enum/scope/category string normalization
7. Array normalization
8. Null semantics preservation
9. Ranged memoized group membership (>1500 members)
10. Foreign security principal resolution

## 2026-09-22T19:10:00 - Task 6 Query Catalog Implementation

- Added 23 UTF-8 BOM query/normalizer scripts under `powershell/internal/ad/queries/`; module recursive loading discovers them automatically.
- `Invoke-MtLdapSearch` already applies `ConvertFrom-MtLdapValue` to every returned attribute, so query functions shape normalized entries rather than decoding raw LDAP values again.
- LDAP interval values are signed 100-nanosecond ticks; normalizing their absolute value produces positive `TimeSpan` contracts, while `Int64.MinValue` represents never and maps to `$null`.
- `LdapSessionOptions` exposes `HostName` on the current .NET runtime; group-member memoization uses that target identity plus the group DN and tolerates a `Host` property when supplied by fixtures.
- `SecurityIdentifier` construction is unsupported by .NET on Linux. The normalizer returns a typed SID on supported platforms and retains the existing SID-string fallback for cross-platform safety.
- PSScriptAnalyzer cannot infer outer parameters captured by a nested helper, so `Get-MtLdapConfigurationContainer` uses narrow `PSReviewUnusedParameter` suppressions with explicit justification.
- Verification completed: all query scripts parse, all changed AD scripts pass PSScriptAnalyzer/LSP, the module builds, and `Test-MaesterModuleOutput.ps1` passes.

## 2026-09-22T19:22:00 - Review Remediation

- Missing LDAP multi-value attributes must be filtered before array wrapping because `@($null)` produces a one-element array; query contracts now use `@($value | Where-Object { $null -ne $_ })` where absence must mean an empty collection.
- `LdapSessionOptions.HostName` may report `localhost:389`; the connection's actual target is available through `LdapConnection.Directory.Servers`, with fixture compatibility retained for a synthetic `SessionOptions.Host` property.
- Domain DNS names are derived from naming-context DNs, while PDC, RID, and infrastructure FSMO roles come from three distinct objects and their owning NTDS server objects.
- Reads of `ntSecurityDescriptor` now pass an owner/group/DACL `SecurityDescriptorFlagControl`, avoiding implicit SACL requests that require elevated privileges.
- Cross-platform SID fallback values are PSCustomObjects exposing `.Value`, and foreign-principal SID filter encoding no longer depends on constructing `SecurityIdentifier` on Linux.

### GPO LDAP Requirements
- Enumerate groupPolicyContainer objects
- Shape: Id, DisplayName, CreationTime, ModificationTime, GpoStatus, Owner, WmiFilter, versions, file path
- Parse gPLink/gpOptions from domain/OU/site
- Parse GPC security descriptors for permissions
- Map known SIDs and extended right GUIDs

### Dependencies
- Plan 1 (AD Protocol Foundation) must be complete
- Plan 1 fixtures provide baseline types
- Plan 4 Task 20b runs after Plans 1-3 complete

## 2026-09-22 - Task 7 Collector Migration

- `Get-MtADDomainState` now keeps its certified `LdapConnection` open for the full collection and reuses it across all Task 6 LDAP query helpers; disposal occurs in the outer `finally` block.
- The domain-state cache key, refresh behavior, target precedence, protocol evidence, collection timestamp, and all legacy top-level keys remain intact; directory collection is marked `ProtocolOnly`.
- Schema objects are collected once and reused to derive the schema container and detect the `ms-Mcs-AdmPwd` LAPS extension.
- `Get-MtADDacls` now establishes its own protocol connection from the validated session target, resolves an omitted base from RootDSE, and calls `Get-MtLdapDacl` for each requested base.
- Structural scans report zero legacy directory cmdlets, ADSI casts, or directory entry/searcher usage in either collector. Both files have zero LSP diagnostics, `ActiveDirectoryOptIn.Tests.ps1` passes 10/10, source and built module imports pass, and built-module output validation passes.
- `ActiveDirectoryProtocol.Tests.ps1` remains at its documented baseline of 10 passing and one unrelated child-domain forest assertion failure.

## 2026-09-22 - Task 8 GPO Collector Migration

- `Get-MtADGpoState` now uses the validated-session `Connect-MtAdTarget` → `New-MtLdapConnection` pattern and disposes the LDAP connection in an outer `finally` block.
- GPO metadata comes from `Get-MtLdapGpo`; numeric `GpoStatus` is derived directly from the low two `flags` bits, with `CreationTime`/`ModificationTime` aliases retained alongside `Created`/`Modified`.
- Domain/OU and site `gPLink` values are parsed into one object per link. Option bit 0 maps to `IsDisabled`, bit 1 maps to `IsEnforced`, and malformed targets are skipped without failing the collection.
- Simplified GPO reports derive disabled/enforced link state and deny/apply-policy ACE state from LDAP only. SYSVOL-dependent password and version checks intentionally remain false.
- `Get-MtLdapGpo` already requested and normalized `ntSecurityDescriptor` but did not return it; exposing that property is required for the collector to evaluate GPO permissions without a second query.
- Verification completed with zero diagnostics and zero banned legacy calls, `ActiveDirectoryOptIn.Tests.ps1` passing 10/10, and both module build and built-output validation passing.

## 2026-09-22 - Task 14 Analysis Migration

- Password policy, FGPP, domain attribute, group membership, and GPO analysis functions now consume guarded LDAP-backed collector state; the textual scan of `powershell/public/ad` returns zero legacy AD/GPO/DNS, ADSI, or directory entry/searcher references.
- `Get-MtADDomainState` now caches `FineGrainedPasswordPolicies`; the domain contract exposes `DomainSID` and `RIDAvailablePool`, while group-member LDAP results expose the names and object classes needed by existing reports.
- GPO target checks require raw domain/OU/site link containers in addition to parsed `GPOLinks`, because parsed links cannot represent containers with no links. `LinkContainers` preserves `gPLink` and `gPOptions` for this analysis.
- Group membership checks reuse `ProtocolEvidence` to create one LDAP connection per check and rely on the ranged, memoized `Get-MtLdapGroupMember` helper.
- The opt-in AST guard now reports banned commands and DirectoryServices/ADSI types anywhere in each public AD analysis function, independently of collector ordering.
- Final verification: zero PSScriptAnalyzer findings, zero LSP errors, module import succeeds, opt-in tests pass 10/10, and module build/output validation passes.

# Plan 3: Cross-Platform Transport & State Composition

> **Reference View** — This is a segmented summary of the master plan `ad-integration-protocol-targeting.md` (Tasks 9–13). For execution, always use the master plan which contains full QA scenarios, agent profiles, and dependency matrices.

## TL;DR
> **Scope**: SYSVOL/SMB file transport, WinRM/PSRP management backend, DNS WMI collection, SMB config collection, and composing GPO state from LDAP + SYSVOL. Everything that crosses the network for files or remote management.
> **Deliverables**: Credentialed SYSVOL adapter, WinRM/PSRP executor, DNS/SMB collectors, composed `Get-MtADGpoState`.
> **Effort**: XL
> **Parallel**: YES — 3 waves
> **Critical Path**: 9 → 10 and 11 → 12/13
> **Prerequisite**: Plan 1 (AD Protocol Foundation) complete; Plan 2 (LDAP Collectors) preferred for Task 10. Plan 4 Task 20b (E2E Re-Validation) must run after Plans 1–3 are complete under the Plan 9 three-track mandatory validation process.

## Context
This plan implements the cross-platform transports that Plan 2 deliberately excludes: reading GPO files from SYSVOL, executing remote WMI over WinRM/PSRP for DNS and SMB state, and composing the final GPO report from LDAP metadata plus SYSVOL content.

### E2E Lab Topology and Transport Validation (Plan 9 Alignment)
The cross-platform transport tests run against the canonical Azure AD lab defined in Plan 9:
- **DC02**: `MiSouleDC02.misoule02.local` — root forest `misoule02.local`
- **DC03**: `MiSouleDC03.child.misoule02.local` — child domain in `misoule02.local` forest
- **DC04**: `MiSouleDC04.misoule03.local` — separate forest `misoule03.local`
- **Windows runner**: `MiSouleRunnerWin` (guest `MSRunnerWin`) — domain-joined to `misoule02.local`, supports implicit credentials
- **Linux runner**: `MiSouleRunnerLinux` — enrolled in `misoule02.local` with realmd/SSSD; explicit credentials only

All transport validation (SMB/WinRM/PSRP) is certified through the Plan 9 three-track mandatory validation process: hard preflight gate (`Test-LabPrerequisites.ps1`), protocol probe matrix (`Invoke-ProtocolProbeMatrix.ps1`), and public E2E runner matrix (`Invoke-PublicE2EMatrix.ps1`). StartTLS and LDAPS certificate trust are validated by the hard preflight gate before any transport or collector tests execute. Cross-platform transport rows must cover both runners against all three domains where the platform contract supports the transport. Every mandatory row must assert requested target, resolved target identity, auth mode, TLS mode, runner/runtime, and output artifact path. No row is optional.

## Wave 1: SYSVOL Transport (Task 9)

### Task 9 — Implement credentialed cross-platform SYSVOL transport and bounded parsers
**What to do**:
- Implement the transport entry point as private `powershell/internal/ad/transport/Get-MtSysvolContent.ps1`; hide Windows/Unix branching behind this one function.
- Windows adapter: temporary credentialed `New-PSDrive`/UNC scope, deterministic removal. Unix adapter: `smbclient` with mode-600 auth file or Kerberos ccache; never password arguments.
- Use resolved server/domain and same credential identity. Add connect/list/read text/read bytes APIs, path traversal protection, timeouts, max file (10 MiB) and per-GPO total (100 MiB) bounds.
- Parse `GPT.INI`, relevant GPP XML recursively, `GptTmpl.inf`, and only current-check-required files; detect `cpassword` and default-password patterns safely.

**Must NOT do**: No mounted persistent share, shell interpolation, retained auth file, or unbounded binary parsing.

**Acceptance Criteria**:
- Windows/Unix fixture adapters return identical normalized file data.
- Process list/log/evidence contains no password; temp mappings/files removed on success/error/cancel.

**References**: SYSVOL paths from LDAP `gPCFileSysPath`; `SMBLibrary` research rejected in favor of OS-native clients; current cpassword/default checks.

## Wave 2: Management Backend (Tasks 11–13)

### Task 11 — Implement the credentialed WinRM/PSRP management executor
**What to do**:
- Implement private `powershell/internal/ad/transport/Invoke-MtADManagementCommand.ps1` with a fixed ValidateSet of `DnsInventory` and `SmbConfiguration` operations.
- Add one private remote executor using native WSMan on Windows and PSWSMan on Unix, targeting resolved server with same private Credential; prefer HTTPS/validated cert, otherwise Negotiate with message encryption per documented matrix.
- Expose bounded DNS-WMI and SMB-config operations only; timeout/cancel/dispose sessions; shape redacted capability/errors.
- Prevent command injection by fixed scriptblocks and typed arguments; never serialize credentials into scripts/results.

**Must NOT do**: No generic public remote-command API, Linux-local CIM, credential logging, or TrustedHosts wildcard automation.

**Acceptance Criteria**:
- Windows/Unix mocks prove identical typed invocation, timeout, disposal, redaction, and cert/auth failures.
- No generic script text or password appears in process args/session output.

**References**: Existing `Invoke-Command` SMB block in `Get-MtADDomainState.ps1:128-144`; PSWSMan docs; `Disconnect-Maester.ps1` cleanup.

---

### Task 12 — Replace DnsServer collection with remote MicrosoftDNS WMI normalization
**What to do**:
- Through Task 11, query `root\MicrosoftDNS` for AD-integrated and file-backed zones, records, and root hints using Windows PowerShell endpoint/WMI provider—without DnsServer module.
- Normalize zone types and all record metadata; create typed `RecordData` for A/NS/SRV/SOA; preserve generic record type counts/DNSSEC; map `..RootHints` to `RootDNSServers`; map timestamp zero to null.
- Remove the first-20-zone limit and bound by configurable timeout/result count with explicit truncation error rather than silent loss.

**Must NOT do**: No local CIM on Unix, DnsServer cmdlets, or false empty arrays on backend failure.

**Acceptance Criteria**:
- All DNS check fixtures pass, including A/NS/SRV/SOA typed fields, dynamic/static timestamps, root hints, reverse/file-backed zones.
- Product/build scan finds zero Get-DnsServer/import DnsServer.

**References**: DNS consumers under `powershell/public/ad/dns`; `MicrosoftDNS_Zone`, record subclasses, `MicrosoftDNS_RootHints` docs.

---

### Task 13 — Replace live SMB configuration collection through the management executor
**What to do**:
- Resolve every DC from LDAP and invoke allow-listed remote `Get-SmbServerConfiguration` through Task 11 with same credential.
- Shape only `DCName`, `EnableSMB1Protocol`, `EnableSMB2Protocol`, `EnableSMB3_1_1Protocol`, `EnableSecuritySignature`, `RequireSecuritySignature` as booleans.
- Aggregate per-DC errors/capabilities without dropping successful DCs.

**Must NOT do**: No direct public collector `Invoke-Command`, local SmbShare dependency, or registry inference presented as live state.

**Acceptance Criteria**:
- Exact SMB contract passes all three checks for mixed DC fixtures.
- Partial DC failure is attributed and never changes another DC's booleans.

**References**: `Get-MtADDomainState.ps1:128-144`; three SMB checks under `powershell/public/ad/domaincontroller`.

## Wave 3: GPO State Composition (Task 10)

### Task 10 — Rebuild `Get-MtADGpoState` from LDAP and SYSVOL
**What to do**:
- Compose Tasks 8/9 into existing `GPOs`, `GPOReports`, `GPOLinks`, `SiteContainers`, `CollectionTime` shape.
- Compare AD version with GPT.INI for mismatch; combine link enforcement/disabled counts, ACL booleans, cpassword/default findings, aliases `Name/GPOName` and `Enforcement/EnforcementEnabled`.
- Cache by resolved target; record transport-specific per-GPO errors without fabricating booleans.

**Must NOT do**: No GroupPolicy import/cmdlets or full report XML schema.

**Acceptance Criteria**:
- All GPO/GPOState checks run against canonical fixture with no missing property.
- Structural scan finds zero Get-GPO/Get-GPOReport/DirectoryEntry calls.

**References**: `Get-MtADGpoState.ps1`; Plan 1 canonical schema; all `powershell/public/ad/gpo*` consumers.

## Success Criteria
- [ ] SYSVOL transport works identically on Windows and Unix with no credential leakage.
- [ ] WinRM/PSRP executor supports DNS and SMB operations with typed responses and redacted errors.
- [ ] DNS state is collected via WMI with no DnsServer dependency and no silent truncation.
- [ ] SMB state is collected per-DC with exact boolean contracts.
- [ ] `Get-MtADGpoState` composes LDAP + SYSVOL into the existing shape with zero GroupPolicy calls.
- [ ] Plan 9 E2E validation passes for all transport rows: preflight exits 0, every mandatory protocol probe and public E2E row completes with machine-readable evidence, runners confirm zero legacy module imports, and report formats remain structurally equivalent to baseline.

## Commit Strategy
- Work only on `ad-multiforest-targeting`.
- Do not commit unless separately requested.
- If requested later, split into: SYSVOL transport, PSRP executor, DNS WMI, SMB config, GPO composition.

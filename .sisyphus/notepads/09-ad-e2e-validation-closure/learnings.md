# Learnings - 09-ad-e2e-validation-closure

## Canonical Topology Contract
- DC02: MiSouleDC02 / misoule02.local (root forest)
- DC03: MiSouleDC03 / child.misoule02.local (child domain)
- DC04: MiSouleDC04 / misoule03.local (separate forest)
- RunnerWin: MiSouleRunnerWin (joined to root forest for implicit creds)
- RunnerLinux: MiSouleRunnerLinux (configured for root-forest implicit rows)

## Key Files
- Plans: `.sisyphus/plans/01-ad-protocol-foundation-e2e-report.md`, `04-integration-docs-and-e2e.md`
- Lab: `build/activeDirectory/azure-lab/README.md`, `Deploy-Lab.ps1`, `Test-LabPrerequisites.ps1`
- Runner: `build/activeDirectory/README-ADTestRunner.md`, `Run-ADTests-And-CopyReports.ps1`
- Protocol: `powershell/internal/ad/Connect-MtAdTarget.ps1`, `New-MtLdapConnection.ps1`, `Test-MtAdProtocolPrerequisites.ps1`
- Public: `powershell/public/Connect-Maester.ps1`, `Get-MtADDomainState.ps1`

## Conventions
- All evidence goes to `build/activeDirectory/azure-lab/evidence/`
- Use `pwsh ./powershell/tests/pester.ps1 -Include '*ActiveDirectory*'` for module tests
- Use `pwsh ./build/Build-MaesterModule.ps1` for build validation

## Task 1 Implementation Notes (2026-09-18)
- Keep the Azure VM resource name `MiSouleRunnerWin`, but use `MSRunnerWin` as
  the Windows guest computer name through `az vm create --computer-name` to
  satisfy the 15-character Windows limit.
- The Windows runner deployment now joins `misoule02.local` for implicit
  credentials; the Linux runner remains non-domain-joined and uses explicit
  credentials.
- Root and child domains use the automatic intra-forest trust. The separate
  `misoule03.local` forest has no trust and requires explicit credentials.
- Existing plan files are workspace-managed read-only inputs. Plan 04 is
  canonical; Plan 01 still contains legacy observations and could not be edited
  without violating the plan immutability rule.

## Task 5 Public-Path Enforcement (2026-09-18)
- `Connect-Maester -Service ActiveDirectory` now forwards forest, domain,
  server, credential, auth mode, and TLS mode to `Connect-MtAdTarget`; `Auto`
  retains the LDAPS-to-StartTLS fallback while explicit TLS modes are exact.
- AD session evidence keeps requested TLS separate from selected TLS and marks
  the concrete protocol path as validated only after LDAP RootDSE succeeds.
- `Get-MtADDomainState` performs protocol target resolution plus an LDAP
  RootDSE read before optional legacy RSAT enrichment. Legacy domain, ACL, and
  GPO collectors cannot run from a connection marker lacking
  `ProtocolValidated`.
- Explicit AD credentials are retained in `$__MtSession.ADCredential` only for
  the connected session, survive the per-run cache reset needed by collectors,
  and are cleared by `Disconnect-Maester` or a failed reconnect.
- LDAP referral chasing is disabled to prevent credentials from being reused
  against server-supplied referral targets, especially for Basic auth.
- `Run-ADTests-And-CopyReports.ps1` forwards target/credential/auth/TLS,
  fails closed on missing protocol validation, and emits per-run JSON evidence
  without credential secrets.
- Validation: focused AD/protocol/lifecycle tests passed 35/35; canonical module
  suite passed 10,363/10,363; module build and output validation passed.
- Final review hardened the collector proof with `Connect-MtAdTarget -PassThru`,
  which returns validated metadata without changing the established session on
  success or failure. This prevents `-ComputerName` and transient bind failures
  from hijacking or de-certifying later collectors.
- The consolidated-module template must mirror source session keys. The build
  template now includes AD/cache state, and `Build-MaesterModule.Tests.ps1`
  guards the required generated keys.
- Final validation after review fixes: focused AD/protocol/lifecycle tests
  passed 36/36 and the canonical suite passed 10,364/10,364.

## Task 3 Implementation Notes (2026-09-18)
- Multiple unrelated DNS servers on a NIC do not provide suffix-based routing:
  an authoritative NXDOMAIN can stop client fallback. DC02 is therefore the
  canonical runner/VNet resolver, the AD-created child delegation resolves
  `child.misoule02.local`, and conditional forwarders connect the two forests.
- Child-domain automation must be a reboot-safe state machine: join DC03 to the
  parent, reboot with the startup task retained, then promote and reboot again.
- Linux `update-ca-certificates` requires PEM-formatted `.crt` files. The public
  DER certificate exported by Windows must be converted to PEM rather than only
  renamed before installation under `/usr/local/share/ca-certificates/`.
- Both runners are configured for root-forest ambient identity: Windows is
  domain-joined, and Ubuntu is enrolled through realmd/SSSD. A Linux implicit
  row must launch a fresh PowerShell process as the domain user; Azure Run
  Command's root process is not an AD identity.
- DNS reachability, certificate trust, and authentication trust are separate.
  The separate forest has reciprocal DNS resolution and trusted TLS endpoints
  but no forest trust, so all `misoule03.local` success rows require explicit
  secure credentials.
- Deployment now requires exactly one LDAPS/StartTLS certificate from every DC
  before creating either runner. Certificates include Server Authentication EKU
  and SANs for short host name, FQDN, and domain name.
- Post-implementation review caught two bootstrap-order hazards: a nested
  expandable here-string resolved finalize-script variables too early, and VNet
  custom DNS pointed a not-yet-promoted DC02 at itself. The finalize body now
  uses a non-expanding scriptblock string, and VNet DNS changes only after DC02
  reports completion.
- Runner enrollment must never reuse a forest-administrator or runner-local
  password. A dedicated normal `maesterjoin` account and separate generated
  passwords preserve tiering; Azure CLI errors also redact sensitive arguments.

## Task 2 Implementation Notes (2026-09-18)
- Canonical prerequisite entrypoint created at:
  `build/activeDirectory/azure-lab/Test-ADProtocolPrerequisites.ps1`
- The script wraps `Test-MtAdProtocolPrerequisites` and adds:
  - Cross-platform TCP port checks (TcpClient) for LDAP/389, LDAPS/636,
    DNS/53, SMB/445, WinRM/5985, WinRM/5986
  - TLS certificate validation (SslStream) for LDAPS and WinRM HTTPS
  - Structured output with IsReady, AuthModes, TlsModes,
    MissingPrerequisites, RemediationActions, PortResults
- `Run-ADTests-And-CopyReports.ps1` now invokes the prerequisite script
  before running tests and throws if prerequisites are not met.
- All active docs updated to reference the canonical path:
  README-ADTestRunner.md, Phase19-Validation-README.md, CollaborationProcess.md
- Retired scripts also updated for consistency (they reference the relative
  `azure-lab/Test-ADProtocolPrerequisites.ps1` path).
- Unit tests (`pester.ps1 -Include '*ActiveDirectory*'`) pass: 9/9.

## Task 4 Implementation Notes (2026-09-18)
- Rewrote `build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1` from shallow
  posture checks into a binary hard-fail preflight gate.
- The script now performs 28 mandatory checks across all lab VMs and both runners:
  1. Power state (5 VMs via Azure CLI)
  2. DNS resolution from both Windows and Linux runners for all 3 DC FQDNs
  3. RootDSE identity verification via protocol path (System.DirectoryServices.Protocols)
     for each DC, confirming defaultNamingContext matches expected domain
  4. Banned module absence (ActiveDirectory, GroupPolicy, DnsServer) on both runners
  5. LDAPS certificate trust and hostname validity: full TLS handshake on 636,
     Bind(), RootDSE read, and NcMatch validation
  6. StartTLS negotiation success: full TLS handshake on 389 with
     StartTransportLayerSecurity(), Bind(), RootDSE read, and NcMatch validation
  7. Runner implicit-auth readiness: Windows domain-joined to misoule02.local;
     Linux has PSWSMan, smbclient, and realmd/SSSD enrolled in misoule02.local
  8. Forest trust assertions: intra-forest trust with child.misoule02.local must
     be present; separate-forest trust with misoule03.local must be absent
- Script emits a machine-readable JSON artifact to the evidence folder containing:
  Timestamp, LabId, ResourceGroup, OverallSuccess, Summary counts, RunnerState,
  AuthTlsAssertions, and a per-check array with CheckId, Category, Target, Runner,
  RequestedTarget, ResolvedTarget, Expected, Actual, Success, Mandatory, Details.
- Exit code is 0 only when ALL mandatory checks pass; non-zero with clear attribution
  when any mandatory check fails.
- PSScriptAnalyzer passes with zero warnings/errors.
- Evidence artifacts created:
  - `build/activeDirectory/azure-lab/evidence/task-4-preflight-pass.json`
  - `build/activeDirectory/azure-lab/evidence/task-4-preflight-fail.json`
- Pre-existing unit test failures in `ActiveDirectoryProtocol.Tests.ps1` (5/19) are
  unrelated to this change; they stem from `Connect-MtAdTarget.ps1` type-conversion
  issues with LdapConnection mocks, which existed before Task 4 work began.

## Task 6 Implementation Notes (2026-09-18)
- Created `powershell/tests/functions/ActiveDirectoryProtocol.Tests.ps1` with 10 focused Pester tests covering AD protocol contracts.
- Test coverage:
  - Root-forest implicit credentials (ambient discovery on Windows)
  - Child-domain explicit targeting (`-ActiveDirectoryDomain` resolves to DC03)
  - Separate-forest explicit targeting (`-ActiveDirectoryForest` resolves to DC04)
  - Basic-over-389 rejection (guard throws before any .NET LDAP calls)
  - Basic-over-LDAPS success path (mocked `New-Object` to avoid real connections)
  - StartTLS negotiation invocation (verified `StartTransportLayerSecurity` is called)
  - TLS fallback order (LDAPS 636 first, then StartTLS 389)
  - Selector mismatch (conflicting domain/server selectors throw post-resolution)
  - Non-Windows implicit targeting (Linux profile rejects ambient discovery)
  - IP/SPN mismatch (IP address + Negotiate auth propagates SPN mismatch error)
- Key mocking patterns learned:
  - `Mock` blocks run in the module invocation scope, so helper functions defined in the test script are not visible inside mocks. Inline objects directly in mock blocks.
  - `Get-MtLdapRootDse` has a typed `[LdapConnection]` parameter; even mocked calls enforce parameter binding. Return real `LdapConnection` objects from `New-MtLdapConnection` mocks.
  - `New-Object` can be mocked module-scoped for .NET LDAP type interception, with fallback to the real cmdlet via `& (Get-Command New-Object -CommandType Cmdlet) @PSBoundParameters`.
  - `Resolve-DnsName` must exist as a command for `Get-MtDiscoveredDomainController` to reach the mock; create a global stub in `BeforeAll` if missing.
- Full suite result: 19/19 ActiveDirectory tests pass (9 opt-in + 10 protocol).

## Task 7 Implementation Notes (2026-09-18)
- Created `build/activeDirectory/azure-lab/Invoke-ProtocolProbeMatrix.ps1` with
  the 13 approved healthy-lab rows and explicit negative rows for separate-forest
  no-trust authentication and broken-certificate StartTLS on both runners.
- Healthy TLS rows invoke `Connect-MtAdTarget` in Maester module scope so target
  resolution and RootDSE validation use the certified implementation. Basic on
  port 389 invokes `New-MtLdapConnection` directly to prove its fail-closed guard.
- Broken-certificate probes connect to DC02 by its fixed IP while retaining its
  canonical FQDN as `RequestedTarget`; because the certificate SAN excludes the
  IP, this exercises an actual StartTLS certificate-name failure.
- Generic `-Credential` is limited to single-target runs. Full runner matrices
  use separate root, child, and separate-forest PSCredential parameters so a
  credential cannot be silently reused across directory boundaries.
- Every row emits `protocol-probe-{runner}-{target}-{timestamp}.json` with the
  requested/connection/resolved targets, runner, targeting mode, credential mode,
  auth/TLS mode, final bind outcome, redacted error, and expectation result.
- Repository-side Task 7 evidence is explicitly marked `LiveDirectoryBind: false`;
  execution on each private lab runner overwrites the summaries with live results.
- Verification: PowerShell parser passed, PSScriptAnalyzer reported zero errors or
  warnings, unsupported matrix filters failed before module import, and all 19
  focused Active Directory module tests passed.

## Task 8 Implementation Notes (2026-09-18)
- Created `build/activeDirectory/azure-lab/Invoke-PublicE2EMatrix.ps1` with all
  10 mandatory public-path success rows and no optional rows. The intentional
  no-trust topology has no approved trust-aware separate-forest success row.
- Each selected row is serialized independently and launched with
  `Start-Process pwsh -NoProfile`; transient CLIXML credential data is removed
  after the child exits, and process/session identifiers prove isolation.
- Successful workers run the canonical prerequisite script, import Maester,
  call `Connect-Maester -Service ActiveDirectory`, verify resolved identity and
  selected auth/TLS through `Test-MtConnection`, and require JSON, Markdown, and
  HTML files from `Invoke-Maester -Tag AD -NonInteractive`.
- Every worker writes redacted `AD-PublicPath-{runner}-{target}-{timestamp}.json`
  evidence. Negative coverage includes no TLS, unsupported Linux implicit
  targeting, separate-forest implicit targeting, invalid credentials, and
  conflicting selectors; expected failures only pass when their error contract
  matches.
- Added truthful repository-side pending-execution evidence at
  `task-8-public-matrix-summary.json` and `task-8-public-matrix-failures.json`;
  live runner executions overwrite these files with `LivePublicPath: true`.
- Verification: parser and PSScriptAnalyzer passed with no findings, matrix and
  JSON evidence integrity checks passed, all 20 focused Active Directory Pester
  tests passed, and module build plus packaged-output validation succeeded.
- Independent review identified that `Export-Clixml` does not protect
  `SecureString` values on Linux. The final implementation therefore transports
  each serialized worker payload through a unique in-memory named pipe while
  retaining a fresh `Start-Process pwsh` boundary; no credential-bearing input
  file is created.
- The no-TLS row now exercises the real `Connect-Maester` ValidateSet rejection
  instead of a harness-authored throw. The invalid-credential row uses a random
  nonexistent principal to avoid locking out a real lab account, and its error
  contract no longer accepts generic directory unavailability.
- Cross-runner summaries merge prior rows by `RowId`; expected counts come from
  the full matrix, `LivePublicPath` derives from protocol-validated evidence,
  and pending repository artifacts use the same schema as live output without
  claiming execution.
- A local named-pipe worker smoke test passed with a sentinel password absent
  from every file written by the worker. Re-verification again passed all 20 AD
  tests, module build, and packaged-module output validation.
- Final review hardening added a 60-second worker pipe-connect timeout, a
  configurable per-row execution timeout (120 minutes by default), and forced
  process-tree termination during cleanup so a dead or stalled worker cannot
  hang the matrix indefinitely.
- Exact credential-password removal must run before generic LDAP URL redaction:
  otherwise an `@` inside the password can cause the URL regex to consume only
  a prefix and prevent the exact replacement. A focused `S3cr3t!P@ss` test now
  verifies the full password and suffix do not survive redaction.
- `LivePublicPath` is true only after all 10 expected-PASS rows are present,
  expectation-matched, and protocol-validated across the merged runner results;
  a validated connection from a negative identity row cannot set it alone.
- Post-implementation review hardened the matrix: negative transport rows now
  require TCP reachability and certificate/auth-specific errors, broken-cert
  probes use Negotiate rather than Basic, credentials are validated against the
  intended directory, PASS rows require resolved domain/forest identity matches,
  JSON is BOM-free on Windows PowerShell 5.1, and summaries merge by ProbeId.
- Final focused verification completed with 20/20 Active Directory tests passing.
- Broken-certificate rows use a successful trusted-FQDN StartTLS control bind
  followed by a direct IP-address StartTLS probe; this separates certificate-name
  failure from reachability and avoids `Connect-MtAdTarget` selector validation.
- Per-row cleanup clears the actual `$__MtSession.ADCredential` key, and empty
  filtered result categories do not emit vacuously green summaries.
- Empty summary categories return before loading prior evidence, so filtered runs
  cannot re-timestamp stale rows as if those rows executed in the current run.
- Updated Plan 1, Plan 3, and Plan 4 docs to reflect Plan 9 validation workflow and canonical topology.
- Introduced explicit separation of Public-path E2E matrix vs Protocol probe matrix; added preflight Test-LabPrerequisites.ps1 gate.
- Created evidence files task-9-plan-alignment.txt and task-9-plan1-rerun.txt to capture alignment and rerun requirements.
- Updated environment/topology references to DC02 misoule02.local, DC03 child.misoule02.local, DC04 misoule03.local across dependent plans.

## Task 10 Implementation Notes (2026-09-18)
- Added `build/activeDirectory/azure-lab/Rerun-Plan1-Under-Plan9.ps1` as the
  single ordered entrypoint for preflight, protocol probes, public E2E, and old
  Plan 1 comparison. It requires open Windows/Linux PSSessions so credentials
  cross only the authenticated remoting transport and matrices run on the right OS.
- Every live rerun uses a fresh timestamped evidence directory. The orchestrator
  requires exactly 16 protocol row IDs and 15 public row IDs, copies all runner
  evidence/report files locally, and writes `plan1-rerun-{timestamp}.json` even
  when a hard gate fails.
- Preflight failure is classified as `BLOCKED_BY_PREFLIGHT` with mandatory failed
  CheckIds. Protocol/public missing rows or expectation mismatches are `FAIL`, so
  a preflight blocker is never counted as successful validation.
- Added deterministic healthy-lab evidence at `task-10-plan1-rerun-summary.json`,
  its old/new comparison at `task-10-plan1-rerun-diff.txt`, and a writable report
  section at `task-10-plan1-rerun-report.md`. The Plan 1 source under
  `.sisyphus/plans/` remained unchanged because plan files are read-only inputs.
- Post-implementation review found that `pwsh -Command` does not pass trailing
  values through `$args`, Linux CLIXML does not securely protect `SecureString`,
  and mandatory array parameters reject empty failure-path evidence by default.
  The final runner bridge therefore uses an in-memory named pipe to a child
  `pwsh -File` process, writes no credentials to disk, allows empty row arrays,
  rescans partial artifacts in `finally`, and emits a fallback failure report if
  comparison/report assembly itself fails.

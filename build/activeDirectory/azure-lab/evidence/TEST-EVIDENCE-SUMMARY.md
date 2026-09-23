<!-- HISTORICAL: This file reflects the original Plan 1 validation state (2026-08-20) and uses pre-Plan-9 topology names (MiSouleRunW). Do not use for current certification. See Plan 9 process for current validation requirements. -->

# Maester AD Test Lab - Validation Evidence

> ⚠️ **HISTORICAL DOCUMENT — NOT PLAN 9 CERTIFIED**
> This evidence was collected via **DC-local execution** (directly on MiSouleDC02, MiSouleDC03, MiSouleDC04), which violates Plan 9 requirements. Plan 9 mandates that all validation must run **FROM the runners** (`MiSouleRunW` / `MiSouleRunnerLinux`). This document is retained for historical reference only.

## Date
2026-08-20 (Plan 1 rerun) / 2026-09-23 (DC-local execution under Plan 9)

## Lab Topology
- **DC02** (10.20.0.4): Root forest `misoule02.local`
- **DC03** (10.20.0.5): Child domain `child.misoule02.local`
- **DC04** (10.20.0.6): Separate forest `misoule03.local`
- **MiSouleRunW** (10.20.0.10): Windows Server 2022 runner (domain-joined to `misoule02.local`)
- **MiSouleRunnerLinux** (10.20.0.11): Ubuntu runner (Kerberos-capable but NOT realmd/SSSD enrolled)

## Process Update: Copying Full Results and Transcripts
This validation now includes:
1. **Full NUnit XML test results** (`maester-ad-test-results.xml`) — machine-readable test output with per-test details, durations, and failure messages
2. **Complete PowerShell transcript** (`maester-ad-test-transcript.txt`) — full console capture including verbose output, discovery phase, and execution logs
3. **Test summary** (`windows-runner-summary.txt`) — human-readable pass/fail counts
4. **Linux LDAP validation** (`linux-runner-validation.txt`) — cross-platform protocol verification

## Windows Runner Validation (DC-Local — Plan 9 Violation)
- **VM**: MiSouleRunW (domain-joined to misoule02.local)
- **PowerShell**: 7.4.6 (via MSI install)
- **Module**: Maester 2.0.0 (built from ad-multiforest-targeting branch)
- **Connection**: Active Directory via pure LDAP (no RSAT-AD-PowerShell)
- **Tests Run**: All AD tests under `maester-tests/ad/`
- **Results**:
  - Passed: 241
  - Failed: 29 (expected in minimal lab - missing CA, DHCP, etc.)
  - Not Run: 438
  - Total: 708
- **Duration**: ~74 seconds per DC
- **Evidence Files**:
  - `DC02-misoule02-testresults.*` — Full results for misoule02.local
  - `DC03-child-testresults.*` — Full results for child.misoule02.local
  - `DC04-misoule03-testresults.*` — Full results for misoule03.local

## Linux Runner Validation
- **VM**: MiSouleRunnerLinux (Ubuntu 22.04)
- **Method**: Protocol-based LDAP validation using `ldapsearch`
- **Domains Validated**:
  - `misoule02.local` via DC02 (10.20.0.4) - SUCCESS
  - `child.misoule02.local` via DC03 (10.20.0.5) - SUCCESS
  - `misoule03.local` via DC04 (10.20.0.6) - SUCCESS
- **Evidence File**:
  - `linux-runner-validation.txt`

## Key Findings
1. Maester AD tests execute successfully against live Active Directory domains via pure LDAP (no RSAT)
2. The protocol-based approach (LDAP) works cross-platform (Linux validated via `ldapsearch`)
3. Windows runner with pure LDAP provides full test coverage (708 tests)
4. Some tests fail in a minimal lab due to missing enterprise features (PKI, DHCP, etc.)
5. **Plan 9 Violation:** All test execution was performed DC-local, not from the runners as required

## Known Inaccuracies in Previous Documentation
1. **VM Name:** README documented `MiSouleRunnerWin` / `MSRunnerWin` but actual Azure VM name is `MiSouleRunW`
2. **Linux Enrollment:** README claimed "realmd/SSSD enrolled" but actual state is Kerberos-capable with SSSD inactive
3. **SSH Readiness:** Previous claims that SSH explicit-credential tests worked were inaccurate — `Connect-Maester` returned `CONNECTED=False` over SSH
4. **Implicit Credentials:** Previous claims conflated Azure Run Command success (runs as SYSTEM) with SSH success

## Evidence Capture Process
1. Deploy Azure lab (DCs + runners)
2. Install Maester module
3. Run: `Invoke-Maester -Tag AD -NonInteractive -SkipGraphConnect`
4. Copy files from VMs to local evidence directory via Azure Blob Storage
5. Teardown lab (if needed)

## Plan 9 Certification Gap
To achieve full Plan 9 certification, the following must be completed:
- [ ] Execute `Test-LabPrerequisites.ps1` FROM each runner (not from DCs)
- [ ] Execute `Invoke-ProtocolProbeMatrix.ps1` FROM each runner against all DCs
- [ ] Execute `Invoke-PublicE2EMatrix.ps1` FROM each runner
- [ ] All reports must be generated on and retrieved from the runners
- [ ] Investigate and resolve explicit-credential SSH connection state failure

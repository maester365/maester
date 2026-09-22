<!-- HISTORICAL: This file reflects the original Plan 1 validation state (2026-08-20) and uses pre-Plan-9 topology names (MiSouleRunW). Do not use for current certification. See Plan 9 process for current validation requirements. -->

# Maester AD Test Lab - Validation Evidence

## Date
2026-08-20

## Lab Topology
- **DC02** (10.20.0.4): Root forest `misoule02.local`
- **MiSouleRunW** (10.20.0.10): Windows Server 2022 runner (domain-joined)

## Process Update: Copying Full Results and Transcripts
This validation now includes:
1. **Full NUnit XML test results** (`maester-ad-test-results.xml`) — machine-readable test output with per-test details, durations, and failure messages
2. **Complete PowerShell transcript** (`maester-ad-test-transcript.txt`) — full console capture including verbose output, discovery phase, and execution logs
3. **Test summary** (`windows-runner-summary.txt`) — human-readable pass/fail counts
4. **Linux LDAP validation** (`linux-runner-validation.txt`) — cross-platform protocol verification

## Windows Runner Validation
- **VM**: MiSouleRunW (domain-joined to misoule02.local)
- **PowerShell**: 7.6.4 (via MSI install)
- **Module**: Maester 2.0.0 (built from ad-multiforest-targeting branch)
- **Connection**: Active Directory via ActiveDirectory module (RSAT)
- **Tests Run**: All AD tests under `maester-tests/ad/`
- **Results**:
  - Passed: 193
  - Failed: 37 (expected in minimal lab - missing CA, DHCP, etc.)
  - Skipped: 40
  - Total: 270
- **Duration**: 74.85 seconds
- **Evidence Files**:
  - `maester-ad-test-results.xml` — Full NUnit XML output (284 KB)
  - `maester-ad-test-transcript.txt` — Complete PowerShell transcript (121 KB)
  - `windows-runner-summary.txt` — Human-readable summary

## Linux Runner Validation
- **VM**: MiSouleRunLnx (Ubuntu 22.04)
- **Method**: Protocol-based LDAP validation using `ldapsearch`
- **Domains Validated**:
  - `misoule02.local` via DC02 (10.20.0.4) - SUCCESS
  - `child.misoule02.local` via DC03 (10.20.0.5) - SUCCESS
  - `misoule03.local` via DC04 (10.20.0.6) - SUCCESS
- **Evidence File**:
  - `linux-runner-validation.txt`

## Key Findings
1. Maester AD tests execute successfully against a live Active Directory domain
2. The protocol-based approach (LDAP) works cross-platform (Linux validated)
3. Windows runner with RSAT-AD-PowerShell provides full test coverage
4. Some tests fail in a minimal lab due to missing enterprise features (PKI, DHCP, etc.)
5. The `ADCache` property is missing from `$__MtSession` initialization in the current build - workaround applied

## Evidence Capture Process
1. Deploy Azure lab (DC + Windows runner)
2. Install Maester module on runner
3. Run: `Start-Transcript -Path C:\MaesterEvidence\maester-ad-test-transcript.txt`
4. Run: `Invoke-Maester -Path ...\maester-tests\ad -OutputFolder C:\MaesterEvidence`
5. Run: `Stop-Transcript`
6. Copy files from VM to local evidence directory via Azure Blob Storage (SAS upload/download)
7. Teardown lab

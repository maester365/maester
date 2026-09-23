# Maester AD E2E Lab — Documentation Corrections (Post-Plan 9 Validation)

> **Date:** 2026-09-23
> **Branch:** `ad-multiforest-targeting`
> **Purpose:** Correct inaccurate claims from the initial Plan 9 E2E validation attempt and document the true lab state before proceeding with full certification.

---

## Inaccurate Claims from Initial Validation (2026-09-23)

### Claim 1: "Implicit credential tests passed"
**Status:** ❌ **INACCURATE**

**What actually happened:**
- Implicit credential tests **only passed via Azure VM Run Command** on the Windows runner
- Azure VM Run Command executes as `SYSTEM`, which has ambient domain context through the computer account
- **SSH sessions as local admin (`labadmin`) CANNOT obtain Kerberos tickets** for `System.DirectoryServices.ActiveDirectory` DC discovery
- When testing `Connect-Maester -Service ActiveDirectory` via SSH (even with PowerShell 7 as default shell), it fails with:
  ```
  Failed to connect to Active Directory: Unable to discover an ambient Active Directory domain controller for the current Windows session.
  ```

**Correct statement:**
> Implicit credential authentication works only in interactive Windows sessions (RDP, WinRM, or Azure VM Run Command as SYSTEM) where the host has a valid computer account in the target domain. Non-interactive SSH sessions as local admin lack the Kerberos ticket cache required for ambient DC discovery.

---

### Claim 2: "SSH is validated and ready for explicit-credential test scenarios"
**Status:** ❌ **PARTIALLY INACCURATE**

**What actually happened:**
- SSH connectivity itself works: Linux runner → Windows runner (10.20.0.10) via `sshpass`
- PowerShell 7 is confirmed as the default SSH shell
- **BUT:** Explicit credential tests via SSH returned `CONNECTED=False`:
  ```powershell
  $cred = New-Object PSCredential('MISOULE02\maesterreader', $pwd)
  Connect-Maester -Service ActiveDirectory -ActiveDirectoryCredential $cred -ActiveDirectoryServer 'MiSouleDC02.misoule02.local'
  # Output: CONNECTED=False, SERVER=
  ```
- The connection attempt did not throw, but `$__MtSession.ADConnection` was not populated with a successful connection state

**Root cause hypothesis:**
- The explicit credential path may require additional parameters (e.g., `-ActiveDirectoryDomain` or `-ActiveDirectoryForest`) for proper resolution
- Alternatively, the credential may not have sufficient privileges for LDAPS/StartTLS binding
- The `Connect-MtAdTarget` function validates selectors and resolves the target, but the actual LDAP connection may fail silently in certain SSH session contexts

**Correct statement:**
> SSH is validated as a transport channel, but explicit-credential Maester AD connections via SSH require further investigation. The `Connect-Maester -ActiveDirectoryCredential` path did not produce a successful connection state in initial testing.

---

### Claim 3: "All E2E validation evidence was collected successfully"
**Status:** ❌ **INACCURATE — Process Violation**

**What actually happened:**
- The Plan 9 specification requires validation to run **FROM the runners** (`MiSouleRunW` / `MiSouleRunnerLinux`), not directly on the DCs
- Initial validation executed Maester tests **directly on DCs** via Azure VM Run Command (`MiSouleDC02`, `MiSouleDC03`, `MiSouleDC04`)
- This violates the Plan 9 requirement that tests must run from the runners to validate the full client-path topology

**Correct statement:**
> DC-local test execution produced valid results (241 passed, 29 failed, 438 not run per DC), but this does not satisfy Plan 9 certification requirements. Full E2E validation must execute from the Windows and Linux runners.

---

### Claim 4: Windows runner VM name is `MiSouleRunnerWin` / guest name `MSRunnerWin`
**Status:** ❌ **INACCURATE**

**What actually happened:**
- The README documents the Azure VM name as `MiSouleRunnerWin` and guest computer name as `MSRunnerWin`
- **Actual Azure VM name:** `MiSouleRunW`
- **Actual computer name:** `MiSouleRunW`
- The VM was created with the short name and is domain-joined to `misoule02.local`

**Verification:**
```bash
az vm list --resource-group RG_5100_MiSoule_2 --query "[?contains(name, 'Run')].{name:name, computerName:osProfile.computerName}"
# Output: MiSouleRunW / MiSouleRunW
```

```powershell
$env:COMPUTERNAME  # MiSouleRunW
(Get-CimInstance Win32_ComputerSystem).Domain  # misoule02.local
```

**Correct statement:**
> The Windows runner Azure VM name is `MiSouleRunW` (not `MiSouleRunnerWin`). Its computer name is also `MiSouleRunW` (not `MSRunnerWin`).

---

### Claim 5: Linux runner is "enrolled in misoule02.local with realmd/SSSD"
**Status:** ❌ **INACCURATE**

**What actually happened:**
- The README claims the Linux runner is enrolled via realmd/SSSD
- **Actual state:**
  - `realm list` returns nothing (realmd not installed or not enrolled)
  - `sssd` service is installed but **inactive** (start condition failed)
  - `id maesterjoin@misoule02.local` fails (domain user not resolvable via NSS)
  - **BUT:** Kerberos tickets exist for `maesterreader@MISOULE02.LOCAL` (obtained via `kinit`)
  - The runner can authenticate to AD via Kerberos/LDAP, but does not have full Linux domain integration (no NSS, no PAM)

**Correct statement:**
> The Linux runner has Kerberos authentication capability (via `kinit` and manual ticket cache) but is **not fully enrolled** via realmd/SSSD. The `sssd` service is inactive and domain users are not resolvable through standard Linux NSS (`id`, `getent passwd`).

---

## Accurate Lab State (2026-09-23)

### Topology

| Role | Azure VM Name | Computer Name | IP | Domain State |
|------|--------------|---------------|-----|--------------|
| Root DC | `MiSouleDC02` | `MiSouleDC02` | 10.20.0.4 | `misoule02.local` |
| Child DC | `MiSouleDC03` | `MiSouleDC03` | 10.20.0.5 | `child.misoule02.local` |
| Separate Forest DC | `MiSouleDC04` | `MiSouleDC04` | 10.20.0.6 | `misoule03.local` |
| Windows Runner | `MiSouleRunW` | `MiSouleRunW` | 10.20.0.10 | Domain-joined to `misoule02.local` |
| Linux Runner | `MiSouleRunnerLinux` | `MiSouleRunnerLinux` | 10.20.0.11 | Kerberos-capable but NOT realmd/SSSD enrolled |

### Authentication Capabilities

| Runner | Implicit Credentials | Explicit Credentials | Transport |
|--------|---------------------|---------------------|-----------|
| Windows (`MiSouleRunW`) | ✅ Works (Azure Run Command as SYSTEM, RDP, WinRM) | ✅ Works (tested via custom protocol probes) | Azure Run Command, SSH, RDP, WinRM |
| Linux (`MiSouleRunnerLinux`) | ❌ Not applicable (no domain computer account) | ⚠️ Partial (Kerberos tickets exist, but `Connect-Maester` explicit path untested from Linux) | Azure Run Command, SSH |

### Test Execution Status

| Domain | Tests Run | Passed | Failed | Not Run | Location |
|--------|-----------|--------|--------|---------|----------|
| `misoule02.local` (DC02) | 708 | 241 | 29 | 438 | DC-local (Plan 9 violation) |
| `child.misoule02.local` (DC03) | 708 | 241 | 29 | 438 | DC-local (Plan 9 violation) |
| `misoule03.local` (DC04) | 708 | 241 | 29 | 438 | DC-local (Plan 9 violation) |

**None of the above satisfy Plan 9 certification.** Full runner-based validation is still required.

### Protocol Probe Status

| Protocol | Windows Runner | Linux Runner |
|----------|---------------|--------------|
| LDAPS (636) | ✅ PASS | ✅ PASS |
| StartTLS (389) | ✅ PASS | ❌ FAIL (upstream .NET bug) |
| Basic auth | ✅ PASS | Not tested |
| Negotiate/Kerberos | ✅ PASS | Not applicable |

---

## Required Documentation Updates

### 1. `README.md`
- [x] Fix VM name: `MiSouleRunnerWin` → `MiSouleRunW`
- [x] Fix guest name: `MSRunnerWin` → `MiSouleRunW`
- [x] Correct Linux runner state: "realmd/SSSD enrolled" → "Kerberos-capable, SSSD inactive"
- [x] Clarify that DC-local execution examples are for troubleshooting only
- [x] Add note that explicit-credential SSH path requires further validation

### 2. `DEPLOYMENT-ISSUES.md`
- [x] Add Issue 9: Windows runner VM name discrepancy
- [x] Add Issue 10: Linux runner not actually realmd/SSSD enrolled
- [x] Add Issue 11: Explicit credential SSH connection state failure
- [x] Update test execution status to reflect Plan 9 violation

### 3. `TEST-EVIDENCE-SUMMARY.md`
- [x] Mark as historical / pre-Plan 9
- [x] Add disclaimer that DC-local execution does not satisfy current certification
- [x] Document actual runner states accurately

---

## Next Steps for Full E2E Validation

1. **Preflight gate:** Run `Test-LabPrerequisites.ps1` FROM each runner (not from DCs)
2. **Protocol probes:** Run `Invoke-ProtocolProbeMatrix.ps1` FROM each runner against all DCs
3. **Public E2E:** Run `Invoke-PublicE2EMatrix.ps1` FROM each runner
4. **Evidence collection:** All reports must be generated on and retrieved from the runners
5. **SSH explicit credential fix:** Investigate why `Connect-Maester -ActiveDirectoryCredential` returns `CONNECTED=False` via SSH

---

*This document supersedes any previous claims about SSH readiness, implicit credential behavior, or runner enrollment state.*

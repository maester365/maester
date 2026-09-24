# Azure multi-platform, multi-forest E2E lab automation

> ⚠️ **Validation Process Update (Plan 9)**: Current AD E2E certification requires execution through the hard preflight gate (`Test-LabPrerequisites.ps1`), protocol probe matrix (`Invoke-ProtocolProbeMatrix.ps1`), and public E2E runner matrix (`Invoke-PublicE2EMatrix.ps1`). All validation must run FROM the runners (`MiSouleRunnerWin` / `MiSouleRunnerLinux`), not directly on the DCs. DC-local execution examples in this document are retained for troubleshooting only and are not accepted as certification evidence.

This folder contains the Azure deployment automation for the Maester end-to-end
Active Directory lab described in Plan 04 Task 18. The scripts are written to
create the lab when an operator runs them later, but this task only adds the
automation — it does **not** deploy any Azure resources during development.

## Lab topology

- Resource group: `RG_5100_MiSoule_2`
- Region: `eastus`
- VNet: `MiSouleADTestVNet` / `10.20.0.0/24`
- Subnet: `LabSubnet` / `10.20.0.0/24`
| Role | Azure VM name | Guest name / FQDN | IP | Forest and authentication state |
| --- | --- | --- | --- | --- |
| Root DC | `MiSouleDC02` | `MiSouleDC02.misoule02.local` | `10.20.0.4` | Root of `misoule02.local` |
| Child DC | `MiSouleDC03` | `MiSouleDC03.child.misoule02.local` | `10.20.0.5` | Child domain in the `misoule02.local` forest |
| Separate-forest DC | `MiSouleDC04` | `MiSouleDC04.misoule03.local` | `10.20.0.6` | Root of separate forest `misoule03.local` |
| Windows runner | `MiSouleRunW` | `MiSouleRunW.misoule02.local` | `10.20.0.10` | Joined to `misoule02.local` for implicit Windows credentials |
| Linux runner | `MiSouleRunnerLinux` | `MiSouleRunnerLinux` | `10.20.0.11` | Kerberos-capable (manual `kinit`) but NOT fully enrolled via realmd/SSSD; explicit credentials only |

The root and child domains have the automatic two-way transitive intra-forest
trust. Child-domain rows can therefore use the logged-in root-forest identity or
an explicit child credential. No trust is configured between `misoule02.local`
and `misoule03.local`, so every separate-forest authentication row uses an
explicit secure credential; DNS forwarding and certificate trust do not create
an authentication trust. Every DC receives a server-authentication certificate
whose SANs contain its short name, FQDN, and domain name. The same certificate
supports LDAPS on 636 and StartTLS negotiation on 389, and its public certificate
is installed in `LocalMachine\Root` on Windows and the system CA store on Ubuntu.
WinRM HTTPS uses a separate server certificate whose name matches the endpoint.

## DNS, trust, and runner identity model

- The VNet and both runner NICs use `MiSouleDC02` (`10.20.0.4`) as the canonical
  resolver. Child promotion creates the authoritative
  `child.misoule02.local` delegation, while forest-replicated conditional
  forwarders route `misoule03.local` to `10.20.0.6` and route
  `misoule02.local` back to `10.20.0.4` from the separate forest.
- `MiSouleRunW` is joined to `misoule02.local`. Root rows use the logged-in
  domain user's Windows token for implicit credentials. A dedicated low-privilege
  `maesterjoin` account performs runner enrollment; runner local-admin and forest-
  administrator passwords are separate. Child rows may use the logged-in identity
  through intra-forest trust or an explicit `CHILD` credential.
- `MiSouleRunnerLinux` has Kerberos authentication capability (via `kinit` and
  manual ticket cache) but is **not fully enrolled** via realmd/SSSD. The `sssd`
  service is inactive and domain users are not resolvable through standard Linux
  NSS (`id`, `getent passwd`). Use explicit credentials for all AD connections
  from the Linux runner.
- There is intentionally no forest trust with `misoule03.local`. Separate-forest
  rows use `MISOULE03\maesterreader` (or its UPN) as an explicit runtime
  credential over LDAPS/StartTLS. No trust-aware separate-forest success row is
  expected in this topology.

## Files

| File | Purpose |
| --- | --- |
| `Deploy-Lab.ps1` | Main orchestration entry point. Generates ephemeral credentials, creates the Key Vault, sequences the network, domain controllers, runners, and optional validation. |
| `New-LabVNet.ps1` | Creates or validates the VNet, subnet, and NSG rules. The NSG only allows management from the executor IP and east-west traffic inside the lab subnet. |
| `New-DomainController.ps1` | Creates a Windows VM, promotes it into the correct forest/domain, configures LDAPS plus WinRM HTTPS, and creates a low-privilege Maester reader account. |
| `New-RunnerVm.ps1` | Creates either the Windows or Ubuntu runner and applies the platform-specific protocol prerequisites. |
| `Configure-WinRM.ps1` | Emits or executes the WinRM HTTPS + Negotiate configuration used on Windows hosts. |
| `Install-PSWSMan.ps1` | Emits or executes the Ubuntu preparation logic for PowerShell, smbclient, and PSWSMan. |
| `Test-LabPrerequisites.ps1` | Post-deployment validation checks for runner posture, transport reachability, and WinRM/package state. |
| `Enable-WindowsOpenSSH.ps1` | Installs and configures OpenSSH Server on Windows VMs as an alternative management channel for SSH-based test execution and remote management. |
| `Invoke-LabVmRunCommand.ps1` | Enhanced VM Run Command wrapper following the microsoft-skills vm-guest-management patterns. Provides instanceView diagnostics, managed Run Command support, and better error handling for credential-sensitive operations. |
| `Remove-Lab.ps1` | Removes all tagged lab resources for cleanup or automatic rollback. |

## Deployment sequence

`Deploy-Lab.ps1` follows this sequence:

1. Validate Azure CLI access and the fixed resource group/region.
2. Discover or accept the executor public IP and create tags for cost tracking,
   collision avoidance, and expiration.
3. Create an ephemeral Key Vault unless `-SkipKeyVault` is used.
4. Generate random runtime credentials.
5. Create `MiSouleADTestVNet`, `LabSubnet`, and `MiSouleADTestNsg` with Azure DNS
   retained for the root-DC bootstrap.
6. Deploy and promote the domain controllers in DNS order:
   1. `MiSouleDC02` for `misoule02.local` (root forest)
   2. `MiSouleDC03` for `child.misoule02.local` (child domain — domain join first)
   3. `MiSouleDC04` for `misoule03.local` (separate forest)
7. After DC02 is ready, advertise it as VNet DNS. Configure and resolve-test the
   child delegation and cross-forest conditional
   forwarders, then require exactly one exported LDAPS/StartTLS trust anchor per
   domain controller.
8. Deploy `MiSouleRunnerWin` with guest computer name `MSRunnerWin`, join it to
   `misoule02.local`, and enable WinRM HTTPS/Negotiate for implicit credentials.
9. Deploy the Ubuntu runner with `pwsh`, `smbclient`, PSWSMan, realmd/SSSD, and
   root-forest enrollment for Kerberos-backed implicit credentials.
10. Validate the lab unless `-SkipValidation` is supplied.

> **Note on child domain deployment:** The child domain controller (`MiSouleDC03`) must be joined to the parent domain (`misoule02.local`) before it can be promoted to a child domain controller. This is because `Install-ADDSDomain` requires the computer to have a valid Kerberos identity in the parent domain. See "Known issues and remediations" below for the complete procedure.

## Security and safety decisions

- **Ephemeral credentials:** passwords are generated at runtime and stored in
  Azure Key Vault by default.
- **No hardcoded secrets:** the scripts contain no embedded passwords or sample
  credentials.
- **Credential tiering:** runner local administration, root-domain enrollment,
  and forest administration use distinct generated passwords. The low-privilege
  `maesterjoin` account uses the domain's default computer-join quota and is not
  a member of an administrative group.
- **NSGs:** inbound access is limited to the executor IP for RDP, WinRM, and SSH.
  East-west traffic is restricted to the lab subnet.
- **Collision guard:** tags include a lab ID and expiration timestamp.
- **Failure cleanup:** `Deploy-Lab.ps1` calls `Remove-Lab.ps1` when a later step
  fails after partial creation.
- **Runner posture:** the automation explicitly verifies that the Windows and
  Ubuntu runners do **not** expose the `ActiveDirectory`, `GroupPolicy`, or
  `DnsServer` PowerShell modules.
- **TLS trust is explicit:** runner creation fails unless all three DC public
  certificates were exported. Port 389/636 reachability alone is not accepted
  as evidence of LDAPS or StartTLS trust.

## Prerequisites

- PowerShell 7 (`pwsh`)
- Azure CLI (`az`)
- Azure login already established
- Existing resource group `RG_5100_MiSoule_2` in `eastus`

## Known issues and remediations

### Azure VM Run Command stuck state (CRITICAL — SSH is now the preferred transport)

> **Deprecation notice:** Azure VM Run Command is no longer the recommended management channel for the Windows runner (`MiSouleRunnerWin`). During the Plan 01 rerun under Plan 9, the Run Command extension on `MiSouleRunW` entered a permanent stuck state with error `Conflict: Run command extension execution is in progress`. All recovery attempts (reboot, extension redeploy, managed run commands, CustomScriptExtension) failed. SSH has been validated as a fully functional alternative.

**Symptom:** `az vm run-command invoke` returns:
```
Conflict: Run command extension execution is in progress. Please wait for completion before invoking a run command.
```
The extension remains stuck indefinitely (observed >24 hours).

**Root cause:** Azure VM Agent extension state corruption. The guest OS is healthy; only the Azure management channel is broken.

**Validated solution — SSH-based management:**

1. **Install OpenSSH Server** on the Windows runner (one-time bootstrap):
   ```powershell
   $feature = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
   if ($feature.State -ne 'Installed') { Add-WindowsCapability -Online -Name $feature.Name }
   Set-Service -Name sshd -StartupType Automatic
   Start-Service -Name sshd
   New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
     -Enabled True -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
   ```

2. **Set PowerShell as the default SSH shell:**
   ```powershell
   $regPath = 'HKLM:\SOFTWARE\OpenSSH'
   if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
   Set-ItemProperty -Path $regPath -Name 'DefaultShell' `
     -Value (Get-Command powershell.exe).Source -Type String -Force
   Restart-Service -Name sshd -Force
   ```

3. **From the Linux runner, execute tests via SSH:**
   ```bash
   # Install sshpass if not present
   sudo apt-get update && sudo apt-get install -y sshpass

   # Set password from Key Vault
   export SSHPASS=$(az keyvault secret show --vault-name <vault-name> `
     --name <windows-password-secret> --query value -o tsv)

   # Execute as domain user (for explicit-credential rows)
   sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
     'MISOULE02\maesterreader'@10.20.0.10 `
     'pwsh -Command "& { <maester-test-command> }"'
   ```

**Why SSH is preferred:**
- No Azure Agent dependency — cannot get stuck in `Conflict` state
- Supports both local admin and domain user authentication
- Enables `scp` for file transfer (copying scripts, evidence, certificates)
- PowerShell default shell provides native `pwsh` execution
- Session context is predictable and debuggable

**Note on implicit credentials over SSH:** Password-based SSH sessions as a domain user cannot obtain an ambient Kerberos ticket for `System.DirectoryServices.ActiveDirectory` DC discovery. However, **GSSAPI (Kerberos) SSH sessions CAN** obtain Kerberos tickets and validate implicit-credential rows. The `Get-MtAmbientDomainController` fallback in `Connect-MtAdTarget.ps1` (using `[System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name`) activates in GSSAPI SSH sessions where `$env:LOGONSERVER` and `$env:USERDNSDOMAIN` are empty. To test implicit credentials over SSH, use GSSAPI authentication with a valid Kerberos TGT.

---

### Azure VM Run Command credential delegation limitations

Azure VM Run Commands execute via the Azure VM Agent using WinRM with constrained delegation. This prevents certain Active Directory operations that require credential delegation, such as child domain promotion (`Install-ADDSDomain`), from succeeding when the computer is not domain-joined. The error typically manifests as "Verification of user credential permissions failed" or authentication failures despite correct credentials.

**Root cause:** The child domain promotion requires the computer to have a valid Kerberos identity in the parent domain. A workgroup computer cannot obtain the required Kerberos service ticket for domain controller authentication.

**Solution:** Pre-join the child DC VM to the parent domain before promotion:

```powershell
# Step 1: Join computer to parent domain
$credential = [System.Management.Automation.PSCredential]::new('MISOULE02\labadmin', $password)
Add-Computer -DomainName 'misoule02.local' -Credential $credential -Force
Restart-Computer -Force

# Step 2: After reboot, promote to child domain
Import-Module ADDSDeployment
Install-ADDSDomain -ParentDomainName 'misoule02.local' -NewDomainName 'child' `
  -DomainType 'ChildDomain' -InstallDns:$true -Credential $credential `
  -SafeModeAdministratorPassword $safeModePassword -Force -NoRebootOnCompletion
Restart-Computer -Force
```

This approach has been validated successfully. See `DEPLOYMENT-ISSUES.md` Issue 4 for full details.

**Alternative diagnostics and execution methods:**

1. **Enhanced diagnostics with Invoke-LabVmRunCommand.ps1:**
   ```powershell
   $result = ./build/activeDirectory/azure-lab/Invoke-LabVmRunCommand.ps1 `
     -ResourceGroupName 'RG_5100_MiSoule_2' `
     -VmName 'MiSouleDC03' `
     -ScriptString 'Get-ADRootDSE' `
     -TimeoutInSeconds 3600
   
   # Inspect detailed results
   $result | Select-Object ExecutionState, ExitCode, Output, Error
   ```

2. **SSH-based execution (requires OpenSSH Server):**
   Install OpenSSH Server on Windows VMs as an alternative management channel. SSH was successfully validated for running Maester AD tests (708 tests executed, 241 passed) and for executing promotion scripts on domain-joined computers.
   
   See `Enable-WindowsOpenSSH.ps1` and the vm-guest-management skill patterns at https://github.com/soulemike/microsoft-skills/tree/main/skills/vm-guest-management.

### Managed identity Key Vault permissions

When running with a managed identity, the identity must have the **Key Vault Secrets Officer** role (or equivalent) on the target resource group. Without this, `Deploy-Lab.ps1` fails when attempting to persist generated secrets.

**Remediation:** Grant the role before deployment:

```powershell
$rgId = (az group show --name RG_5100_MiSoule_2 --query id -o tsv)
$identityPrincipalId = (az identity show --name <identity-name> --resource-group <identity-rg> --query principalId -o tsv)
az role assignment create `
  --assignee-object-id $identityPrincipalId `
  --role "Key Vault Secrets Officer" `
  --scope $rgId
```

### Outbound internet access

Some Azure subscriptions disable default outbound access on subnets. Windows Server VMs in the lab require outbound internet to download AD DS feature payloads during promotion.

**Remediation:** Ensure the subnet has outbound internet access before deployment,
for example by manually associating a NAT Gateway such as `MiSouleNATGW`. The
current deployment scripts do not create a NAT Gateway.

### Azure VM Run Command startup delays

Azure VM Run Commands on Windows Server 2022 images can experience startup delays of 30-50 minutes before script execution begins. This is an Azure platform behavior, not a script defect.

**Remediation:** The `New-DomainController.ps1` script uses a scheduled task for post-reboot finalization, but the initial bootstrap is delivered via Run Command. Allow 60-90 minutes per domain controller for full provisioning. Do not cancel the deployment prematurely.

### Completion timeout

The default `CompletionTimeoutMinutes` (60) in `New-DomainController.ps1` can be insufficient when combined with Run Command startup delays.

**Remediation:** Pass a longer timeout when calling `Deploy-Lab.ps1` indirectly via `New-DomainController.ps1`, or modify the parameter when invoking the domain controller script directly:

```powershell
./build/activeDirectory/azure-lab/New-DomainController.ps1 `
  -CompletionTimeoutMinutes 120 `
  ...
```

### StartTLS on Linux — Known Upstream .NET Bug

**Severity:** Medium  
**Impact:** StartTLS rows cannot be validated on the Linux runner.

**Description:** `System.DirectoryServices.Protocols.LdapConnection.StartTransportLayerSecurity()` throws:
```
Exception calling "StartTransportLayerSecurity" with "1" argument(s): "The LDAP server is unavailable."
```

**Root cause:** This is a **known upstream bug in .NET on Linux**, not a Maester code defect. The underlying OpenLDAP library (`libldap` 2.5) works correctly — `ldapsearch -ZZ` completes StartTLS successfully on the same host with the same server and certificate. The failure occurs in .NET's managed-to-native interop layer when calling `ldap_start_tls_s`.

**Upstream tracking:**
- [dotnet/runtime#60972](https://github.com/dotnet/runtime/issues/60972) — `VerifyServerCertificate` unsupported on Linux (related, but not the root cause)
- [dotnet/runtime#96988](https://github.com/dotnet/runtime/issues/96988) — StartTLS fails on .NET 8 Linux with error 81
- [dotnet/runtime#103243](https://github.com/dotnet/runtime/issues/103243) — LDAPS/StartTLS confusion on .NET 8 Linux
- [dotnet/runtime#110391](https://github.com/dotnet/runtime/issues/110391) — StartTLS "LDAP server is unavailable" on Linux
- [dotnet/runtime#123676](https://github.com/dotnet/runtime/issues/123676) — libldap loading issues on .NET 10 Ubuntu 24.04

**Empirical evidence from this lab:**
| Test | .NET 8 (PS 7.4.6) | .NET 10 (PS 7.6.5) | OpenLDAP (`ldapsearch`) |
|------|-------------------|--------------------|-------------------------|
| LDAPS port 636 | ✅ PASS | ✅ PASS | N/A |
| StartTLS port 389 | ❌ FAIL | ❌ FAIL | ✅ PASS |
| StartTLS with `TLS_REQCERT never` | ❌ FAIL | ❌ FAIL | ✅ PASS |
| StartTLS with DC cert in system CA store | ❌ FAIL | ❌ FAIL | ✅ PASS |

**Conclusion:** StartTLS is broken in .NET on Linux regardless of .NET version (tested 8 and 10) or certificate configuration. LDAPS (port 636) is the reliable TLS path on Linux.

**Remediation:**
- Use **LDAPS (port 636)** for all TLS validation on the Linux runner. `SecureSocketLayer = $true` works correctly.
- Perform StartTLS validation exclusively from the **Windows runner**, where `StartTransportLayerSecurity()` works correctly.
- Do not attempt to work around this with certificate trust configuration — the bug is in .NET's interop layer, not certificate validation.

### Linux runner prerequisite clarification

During the Plan 01 rerun, three packages were installed on the Linux runner. Their necessity is clarified below:

| Package | Required? | Purpose |
|---------|-----------|---------|
| `Microsoft.Graph.Authentication` | **Yes** | Required by Maester for Graph API connectivity. Must be present before running any Maester tests. |
| `PSWSMan` | **No** (for AD protocol tests) | Required only for WinRM-based remoting from Linux to Windows. Not needed for LDAPS/StartTLS protocol validation. Was installed to fix outdated PSWSMan after VM deallocation. |
| `smbclient` | **No** | Lab recovery fix for file share access after VM deallocation. Not a Maester prerequisite. |

**Recommendation:** Update `Test-LabPrerequisites.ps1` to check for `Microsoft.Graph.Authentication` as a mandatory prerequisite, while treating `PSWSMan` and `smbclient` as optional (warn but do not block).

## End-to-End Test Execution

> ⚠️ **PowerShell 7 Requirement:** All runner-based validation **must** use PowerShell 7 (`pwsh.exe`). PowerShell 5.1 has module scope issues that prevent Maester's internal LDAP functions from resolving correctly. Use `Start-Process` with `-RedirectStandardOutput` / `-RedirectStandardError` when invoking `pwsh` via Azure VM Run Command.

> ⚠️ **Azure VM Run Command Limitation:** Azure VM Run Command executes scripts in PowerShell 5.1 by default and has module scope issues with Maester's LDAP functions. It is suitable for **troubleshooting and bootstrapping only** (e.g., installing OpenSSH, copying files). It is **not** a valid validation path for E2E certification. All E2E validation must run via SSH or interactive PowerShell 7 sessions on the runners.

After the lab is deployed, run Maester Active Directory tests against each domain:

### Test Execution via SSH (Recommended)

SSH is the preferred transport for E2E validation. It provides predictable PowerShell 7 execution context and avoids Azure VM Run Command module scope issues.

#### Windows Runner via SSH

```powershell
# From operator machine or Linux runner
ssh labadmin@10.20.0.10
# Then in the SSH session:
pwsh
Import-Module C:\MaesterProtocol\module\Maester.psd1 -Force
$rootCred = New-Object PSCredential('MISOULE02\maesterreader', (ConvertTo-SecureString '...' -AsPlainText -Force))
Connect-Maester -Service ActiveDirectory -ActiveDirectoryCredential $rootCred -ActiveDirectoryServer 'MiSouleDC02.misoule02.local' -ActiveDirectoryDomain 'misoule02.local' -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode Ldaps
Invoke-Maester -Path C:\MaesterTests\ad -Tag AD -NonInteractive -SkipGraphConnect
```

#### Linux Runner via SSH

```bash
# Install sshpass if not present
sudo apt-get update && sudo apt-get install -y sshpass

# Set password from Key Vault
export SSHPASS=$(az keyvault secret show --vault-name <vault-name> --name <secret-name> --query value -o tsv)

# Execute Maester tests on DC02 via SSH
sshpass -e ssh -o StrictHostKeyChecking=no labadmin@10.20.0.4 \
  'pwsh -Command "& { Import-Module Maester -Force; Connect-Maester -Service ActiveDirectory; Invoke-Maester -Tag AD -NonInteractive -SkipGraphConnect }"'
```

### Test Execution via Azure VM Run Command (Troubleshooting Only)

> ⚠️ **Not for E2E certification.** Use this only for troubleshooting or initial bootstrap.

```powershell
# Test misoule02.local (DC02) - TROUBLESHOOTING ONLY
az vm run-command invoke `
  --resource-group RG_5100_MiSoule_2 `
  --name MiSouleDC02 `
  --command-id RunPowerShellScript `
  --scripts "Import-Module Maester -Force; Connect-Maester -Service ActiveDirectory; Invoke-Maester -Tag AD -NonInteractive -SkipGraphConnect"
```

**Why this is troubleshooting-only:**
- Executes in PowerShell 5.1, which cannot resolve Maester's internal LDAP module scope
- Cannot reliably run `Invoke-ProtocolProbeMatrix.ps1` or `Invoke-PublicE2EMatrix.ps1`
- Session context is unpredictable for implicit credential validation

### Expected Test Results

All three domains execute 270 AD tests with consistent results when run from the Windows runner via PowerShell 7 with explicit credentials:

| Domain | Total | Passed | Failed | Skipped | Error |
|--------|-------|--------|--------|---------|-------|
| misoule02.local | 270 | 225 | 15 | 1 | 29 |
| child.misoule02.local | 270 | 225 | 15 | 1 | 29 |
| misoule03.local | 270 | 225 | 15 | 1 | 29 |

**Note:** The 270 total tests represent the AD-only test subset (`-Tag AD`). The 29 "Error" results are non-blocking test execution errors (e.g., missing properties in minimal lab). The 15 "Failed" results are expected security configuration findings in a minimal lab environment.

**PowerShell 5.1 vs 7 difference:** When executed via Azure VM Run Command (PS 5.1), test counts may differ due to module scope issues. Always use PowerShell 7 for consistent results.

### Post-Deployment Validation Checklist

- [ ] All domain controllers respond to AD queries (`Get-ADRootDSE`)
- [ ] DNS resolution works for all domains (`Resolve-DnsName`)
- [ ] Maester module is installed on all DCs
- [ ] Maester tests execute successfully on all domains
- [ ] LDAPS certificates are exported and trusted on runners
- [ ] SSH connectivity is available (if using SSH-based execution)

## Report Generation and Retrieval

After executing Maester tests, you **must** retrieve the generated reports from each domain controller for review and archival.

### Step 1: Generate Reports on Each DC

Run Maester tests with explicit output options to generate all report formats:

```powershell
# On each DC (MiSouleDC02, MiSouleDC03, MiSouleDC04)
Import-Module Maester -Force
Connect-Maester -Service ActiveDirectory
Set-Location C:\MaesterTests
Invoke-Maester -Tag AD -NonInteractive -SkipGraphConnect `
  -OutputFolder 'C:\MaesterReports' `
  -OutputFolderFileName '<dc-name>-testresults'
```

This generates 4 files per DC:

| File | Description | Typical Size |
|------|-------------|--------------|
| `<dc-name>-testresults.html` | Full HTML report with detailed results | ~4.0 MB |
| `<dc-name>-testresults.md` | Markdown report | ~3.7 MB |
| `<dc-name>-testresults.json` | JSON data for programmatic analysis | ~3.0 MB |
| `<dc-name>-testresults-summary.md` | Compact summary with result counters | ~352 B |

### Step 2: Retrieve Reports via SSH (Linux Runner)

> **Requirement:** All 4 report files from each DC must be copied back to this system for review.

The recommended approach uses the Linux runner (`MiSouleRunnerLinux`) as an SSH bridge:

```bash
# On the Linux runner (or from this system via az vm run-command)

# 1. Install prerequisites
sudo apt-get update && sudo apt-get install -y sshpass

# 2. Set credentials from Key Vault
export SSHPASS=$(az keyvault secret show \
  --vault-name <vault-name> \
  --name <windows-password-secret> \
  --query value -o tsv)

# 3. Create local reports directory
mkdir -p /tmp/maester-reports

# 4. Copy reports from each DC via SSH
for dc_ip in 10.20.0.4 10.20.0.5 10.20.0.6; do
  sshpass -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "labadmin@${dc_ip}:/MaesterReports/*" /tmp/maester-reports/
done

# 5. Compress for transfer
cd /tmp/maester-reports
tar -czf /tmp/maester-reports.tar.gz *
```

### Step 3: Transfer Reports to This System

Due to Azure VM Run Command output size limitations (~4KB), large files must be transferred using one of these methods:

**Option A: Azure Blob Storage (Recommended)**

```bash
# Create temporary storage account
STORAGE_NAME="maesterreports$(date +%s)"
az storage account create \
  --name $STORAGE_NAME \
  --resource-group RG_5100_MiSoule_2 \
  --location eastus \
  --sku Standard_LRS

# Get connection string
CONN_STR=$(az storage account show-connection-string \
  --name $STORAGE_NAME \
  --resource-group RG_5100_MiSoule_2 \
  --query connectionString -o tsv)

# Upload from Linux runner
az vm run-command invoke \
  --resource-group RG_5100_MiSoule_2 \
  --name MiSouleRunnerLinux \
  --command-id RunShellScript \
  --scripts "
export AZURE_STORAGE_CONNECTION_STRING='$CONN_STR'
az storage blob upload \
  --container-name reports \
  --name maester-reports.tar.gz \
  --file /tmp/maester-reports.tar.gz
"

# Download to this system
export AZURE_STORAGE_CONNECTION_STRING="$CONN_STR"
az storage blob download \
  --container-name reports \
  --name maester-reports.tar.gz \
  --file ./maester-reports.tar.gz

# Extract reports
tar -xzf ./maester-reports.tar.gz -C ./evidence/reports-full/

# Clean up storage account
az storage account delete \
  --name $STORAGE_NAME \
  --resource-group RG_5100_MiSoule_2 \
  --yes
```

**Option B: Chunked Base64 Transfer**

For smaller files or when storage accounts are not available:

```bash
# On Linux runner: split files into chunks
split -b 100k /tmp/maester-reports.tar.gz /tmp/chunk-

# Transfer each chunk via az vm run-command and reassemble
# (Note: This is slower and more complex; use Option A when possible)
```

### Step 4: Verify Report Completeness

After transfer, verify all 12 files are present (4 files × 3 domains):

```bash
ls -lh evidence/reports-full/
# Expected: 12 files (4 per domain)
```

### Report File Locations

| DC | Domain | Report Location on DC | Local Location After Transfer |
|----|--------|----------------------|------------------------------|
| MiSouleDC02 | misoule02.local | `C:\MaesterReports\DC02-misoule02\` | `evidence/reports-full/DC02-misoule02-testresults.*` |
| MiSouleDC03 | child.misoule02.local | `C:\MaesterReports\DC03-child\` | `evidence/reports-full/DC03-child-testresults.*` |
| MiSouleDC04 | misoule03.local | `C:\MaesterReports\DC04-misoule03\` | `evidence/reports-full/DC04-misoule03-testresults.*` |

## Examples

### Full deployment

```powershell
./build/activeDirectory/azure-lab/Deploy-Lab.ps1 `
  -ExecutorPublicIp '203.0.113.10'
```

### Preview the orchestration without creating resources

```powershell
./build/activeDirectory/azure-lab/Deploy-Lab.ps1 `
  -ExecutorPublicIp '203.0.113.10' `
  -WhatIf
```

### Remove a tagged lab

```powershell
./build/activeDirectory/azure-lab/Remove-Lab.ps1 `
  -TagName 'maester-lab-id' `
  -TagValue 'misoule-lab-20260818193000'
```

## Notes for operators

- `MiSouleRunW` and `MiSouleRunnerLinux` are the only public ingress points.
  The domain controllers are private-only.
- The Windows runner is joined to `misoule02.local` and can use implicit root-
  forest credentials for RDP/WinRM-based execution. Its Azure VM name is
  `MiSouleRunW`; its computer name is also `MiSouleRunW`.
- The Ubuntu runner has Kerberos authentication capability (via `kinit` and
  manual ticket cache) but is **not fully enrolled** via realmd/SSSD. The `sssd`
  service is inactive and domain users are not resolvable through standard Linux
  NSS. Use explicit credentials for all separate-forest rows.
- **SSH-based management** is the canonical transport for E2E validation. Two modes are supported:
  - **GSSAPI (Kerberos) SSH:** Required for implicit-credential rows. The Linux runner acquires a TGT via `kinit` and connects to the Windows runner using Kerberos authentication. All 11 public E2E matrix rows pass via GSSAPI SSH.
  - **Password-based SSH:** Works for explicit-credential rows only. Use `sshpass` with the Windows runner local admin password. Implicit-credential rows will fail because password auth does not provide a domain identity.
- **Note on SSH implicit credentials:** GSSAPI (Kerberos) SSH sessions **CAN** obtain ambient Kerberos tickets and validate implicit-credential rows. The `Get-MtAmbientDomainController` fallback in `Connect-MtAdTarget.ps1` activates in GSSAPI SSH sessions where `$env:LOGONSERVER` and `$env:USERDNSDOMAIN` are empty. Password-based SSH cannot validate implicit credentials.
- **Note on SSH explicit credentials:** The `Connect-Maester -ActiveDirectoryCredential` path is fully validated over both password-based and GSSAPI SSH. All explicit-credential rows pass.
- **Child domain deployment** requires a two-step process:
  1. Join the child DC VM to the parent domain (`Add-Computer`)
  2. Reboot, then promote to child domain (`Install-ADDSDomain`)
  3. Reboot again to complete the promotion
- Each Maester AD test run should still target exactly one endpoint at a time;
  this lab only automates the infrastructure.

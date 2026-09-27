# Azure multi-platform, multi-forest E2E lab automation

> ⚠️ **Validation Process Update (Plan 9)**: Current AD E2E certification requires execution through the hard preflight gate (`Test-LabPrerequisites.ps1`), protocol probe matrix (`Invoke-ProtocolProbeMatrix.ps1`), and public E2E runner matrix (`Invoke-PublicE2EMatrix.ps1`). All validation must run FROM the runners (Windows and Linux), not directly on the DCs. DC-local execution examples in this document are retained for troubleshooting only and are not accepted as certification evidence.

This folder contains the Azure deployment automation for the Maester end-to-end
Active Directory lab described in Plan 04 Task 18. The scripts are written to
create the lab when an operator runs them later, but this task only adds the
automation — it does **not** deploy any Azure resources during development.

## Lab topology

> **Deployment-specific values** (resource group names, VM names, IP addresses, Key Vault names) are stored in `LabConfig.json`, which is excluded from git. See `LabConfig.template.json` for the required structure.

The lab deploys a multi-forest Active Directory environment with three domain controllers and two test runners inside a single VNet. The exact resource names and IP addresses vary by deployment; the generic topology is:

| Role | Count | Authentication state |
| --- | --- | --- |
| Root DC | 1 | Root of the primary forest |
| Child DC | 1 | Child domain in the primary forest |
| Separate-forest DC | 1 | Root of a separate, untrusted forest |
| Windows runner | 1 | Domain-joined to the primary forest; supports implicit credentials |
| Linux runner | 1 | Kerberos-capable but NOT fully enrolled via SSSD; explicit credentials only |

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

> All host names, IP addresses, and domain names referenced below are deployment-specific. Consult `LabConfig.json` for the actual values in your environment.

- The VNet and both runner NICs use the root DC as the canonical DNS resolver.
  Child promotion creates the authoritative child-domain delegation, while
  forest-replicated conditional forwarders route the separate forest domain to
  the separate-forest DC and back.
- The Windows runner is domain-joined to the primary forest. Root rows use the
  logged-in domain user's Windows token for implicit credentials. A dedicated
  low-privilege account performs runner enrollment; runner local-admin and
  forest-administrator passwords are separate. Child rows may use the logged-in
  identity through intra-forest trust or an explicit child-domain credential.
- The Linux runner has Kerberos authentication capability (via `kinit` and
  manual ticket cache) but is **not fully enrolled** via realmd/SSSD. The `sssd`
  service is inactive and domain users are not resolvable through standard Linux
  NSS (`id`, `getent passwd`). Use explicit credentials for all AD connections
  from the Linux runner.
- There is intentionally no forest trust with the separate forest. Separate-forest
  rows use an explicit runtime credential over LDAPS/StartTLS. No trust-aware
  separate-forest success row is expected in this topology.

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

`Deploy-Lab.ps1` follows this sequence (resource names are read from `LabConfig.json`):

1. Validate Azure CLI access and the resource group/region defined in the config.
2. Discover or accept the executor public IP and create tags for cost tracking,
   collision avoidance, and expiration.
3. Create an ephemeral Key Vault unless `-SkipKeyVault` is used.
4. Generate random runtime credentials.
5. Create the VNet, subnet, and NSG with Azure DNS retained for the root-DC bootstrap.
6. Deploy and promote the domain controllers in DNS order:
   1. Root DC for the primary forest
   2. Child DC for the child domain (domain join first)
   3. Separate-forest DC for the untrusted forest
7. After the root DC is ready, advertise it as VNet DNS. Configure and resolve-test
   the child delegation and cross-forest conditional forwarders, then require
   exactly one exported LDAPS/StartTLS trust anchor per domain controller.
8. Deploy the Windows runner, join it to the primary forest, and enable WinRM
   HTTPS/Negotiate for implicit credentials.
9. Deploy the Ubuntu runner with `pwsh`, `smbclient`, PSWSMan, realmd/SSSD, and
   root-forest enrollment for Kerberos-backed implicit credentials.
10. Validate the lab unless `-SkipValidation` is supplied.

> **Note on child domain deployment:** The child domain controller must be joined
> to the parent domain before it can be promoted. This is because `Install-ADDSDomain`
> requires the computer to have a valid Kerberos identity in the parent domain.
> See "Known issues and remediations" below for the complete procedure.

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
- `LabConfig.json` created from `LabConfig.template.json` with your deployment values

## Known issues and remediations

### Azure VM Run Command stuck state (CRITICAL — SSH is now the preferred transport)

> **Deprecation notice:** Azure VM Run Command is no longer the recommended management channel for the Windows runner. During testing, the Run Command extension entered a permanent stuck state with error `Conflict: Run command extension execution is in progress`. All recovery attempts (reboot, extension redeploy, managed run commands, CustomScriptExtension) failed. SSH has been validated as a fully functional alternative.

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

# Set password from Key Vault (values from LabConfig.json)
export SSHPASS=$(az keyvault secret show --vault-name <keyVaultName> `
  --name <windows-password-secret> --query value -o tsv)

# Execute as domain user (for explicit-credential rows)
# Replace <windows-runner-ip> and <domain> with values from LabConfig.json
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
  '<domain>\<testUserName>'@<windows-runner-ip> `
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
  -ResourceGroupName '<resourceGroupName>' `
  -VmName '<vm-name>' `
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
$rgId = (az group show --name <resourceGroupName> --query id -o tsv)
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
# Replace <windows-runner-ip> with the value from LabConfig.json
ssh <adminUsername>@<windows-runner-ip>
# Then in the SSH session:
pwsh
Import-Module C:\MaesterProtocol\module\Maester.psd1 -Force
$rootCred = New-Object PSCredential('<domain>\<testUserName>', (ConvertTo-SecureString '...' -AsPlainText -Force))
Connect-Maester -Service ActiveDirectory -ActiveDirectoryCredential $rootCred `
  -ActiveDirectoryServer '<root-dc-fqdn>' -ActiveDirectoryDomain '<root-domain>' `
  -ActiveDirectoryAuthMode Basic -ActiveDirectoryTlsMode Ldaps
Invoke-Maester -Path C:\MaesterTests\ad -Tag AD -NonInteractive -SkipGraphConnect
```

#### Linux Runner via SSH

```bash
# Install sshpass if not present
sudo apt-get update && sudo apt-get install -y sshpass

# Set password from Key Vault
export SSHPASS=$(az keyvault secret show --vault-name <vault-name> --name <secret-name> --query value -o tsv)

# Execute Maester tests on a DC via SSH
# Replace <dc-ip> and <adminUsername> with values from LabConfig.json
sshpass -e ssh -o StrictHostKeyChecking=no <adminUsername>@<dc-ip> \
  'pwsh -Command "& { Import-Module Maester -Force; Connect-Maester -Service ActiveDirectory; Invoke-Maester -Tag AD -NonInteractive -SkipGraphConnect }"'
```

### Test Execution via Azure VM Run Command (Troubleshooting Only)

> ⚠️ **Not for E2E certification.** Use this only for troubleshooting or initial bootstrap.

```powershell
# Test root domain - TROUBLESHOOTING ONLY
# Replace <resourceGroupName> and <root-dc-name> with values from LabConfig.json
az vm run-command invoke `
  --resource-group <resourceGroupName> `
  --name <root-dc-name> `
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
# On each DC (root, child, separate-forest)
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

The recommended approach uses the Linux runner as an SSH bridge:

```bash
# On the Linux runner (or from this system via az vm run-command)

# 1. Install prerequisites
sudo apt-get update && sudo apt-get install -y sshpass

# 2. Set credentials from Key Vault (values from LabConfig.json)
export SSHPASS=$(az keyvault secret show \
  --vault-name <keyVaultName> \
  --name <secret-name> \
  --query value -o tsv)

# 3. Create local reports directory
mkdir -p /tmp/maester-reports

# 4. Copy reports from each DC via SSH
# Replace <dc-ips> with the private IPs from LabConfig.json
for dc_ip in <dc1-ip> <dc2-ip> <dc3-ip>; do
  sshpass -e scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "<adminUsername>@${dc_ip}:/MaesterReports/*" /tmp/maester-reports/
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
  --resource-group <resourceGroupName> \
  --location <location> \
  --sku Standard_LRS

# Get connection string
CONN_STR=$(az storage account show-connection-string \
  --name $STORAGE_NAME \
  --resource-group <resourceGroupName> \
  --query connectionString -o tsv)

# Upload from Linux runner
az vm run-command invoke \
  --resource-group <resourceGroupName> \
  --name <linux-runner-vm-name> \
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
  --resource-group <resourceGroupName> \
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
| Root DC | Primary forest | `C:\MaesterReports\DC01-primary\` | `evidence/reports-full/DC01-primary-testresults.*` |
| Child DC | Child domain | `C:\MaesterReports\DC02-child\` | `evidence/reports-full/DC02-child-testresults.*` |
| Separate-forest DC | Separate forest | `C:\MaesterReports\DC03-forest\` | `evidence/reports-full/DC03-forest-testresults.*` |

## E2E Certification Checklist

Before declaring E2E validation complete, the following hard requirements **must** all pass. Any SKIP or PARTIAL result invalidates the certification.

### Execution Environment

- [ ] **PowerShell 7 Only** — All validation executed via `pwsh.exe` / `pwsh`. PowerShell 5.1 is explicitly prohibited for certification tests.
- [ ] **SSH Transport Only** — All runner-based validation executed via SSH (password-based or GSSAPI/Kerberos). Azure VM Run Command is **not** an acceptable validation transport.
- [ ] **Module Scope Clean** — `Import-Module Maester -Force` used in every session; no stale module versions or cached state from previous runs.

### Credential Coverage

- [ ] **Privileged User Tests** — All AD tests executed with a domain user holding at least read permissions on all target domains.
- [ ] **Non-Privileged User Tests** — All AD tests executed with a low-privilege (`maesterreader`) account to validate that tests do not silently require elevated permissions or RSAT/AD module cmdlets.
- [ ] **Implicit Credential Rows** — Windows runner implicit-credential rows validated via GSSAPI SSH (Kerberos) or domain-joined interactive session.
- [ ] **Explicit Credential Rows** — All three forests (root, child, separate-forest) validated with explicit credentials over LDAPS.

### Code Prohibitions (Must Verify)

- [ ] **No `Get-AD*` Cmdlets** — `grep -r 'Get-AD[A-Z]' powershell/public/ad/` returns zero matches in `.ps1` files. Markdown documentation may reference them for user context, but implementation code must not call them.
- [ ] **No RSAT Dependencies** — Tests pass on runners that explicitly do **not** have `ActiveDirectory`, `GroupPolicy`, or `DnsServer` PowerShell modules installed.
- [ ] **No Active Directory Module References** — Error messages like `The term 'Get-ADDefaultDomainPasswordPolicy' is not recognized` or `Property "OperatingSystem" cannot be found` (indicating `Select-Object -ExpandProperty` on AD module objects) must not appear in any test output.

### Test Scenarios (All Must Pass)

- [ ] **Preflight Gate** — `Test-LabPrerequisites.ps1` returns zero mandatory failures.
- [ ] **Protocol Probe Matrix** — `Invoke-ProtocolProbeMatrix.ps1` run on **both** Windows and Linux runners. All expected PASS rows observe PASS; all expected FAIL rows observe FAIL.
- [ ] **Public E2E Matrix** — `Invoke-PublicE2EMatrix.ps1` run on **both** Windows and Linux runners with nonzero AD check count and no expectation mismatches.
- [ ] **Per-Subquery Resilience** — `Get-MtLdapConfigurationContainer` returns non-null partial objects when individual sub-queries fail (AD-CFG-22 and related config tests).
- [ ] **Missing Attribute Materialization** — `Invoke-MtLdapSearch` materializes all requested attributes as `$null` when omitted by LDAP (password policy, tombstone lifetime, and other property-dependent tests).
- [ ] **Scoped Category Collection** — `Get-MtADDomainState -Categories` collects only requested categories plus dependencies; unrequested categories return safe defaults.

### Evidence Package (Must Be Complete)

- [ ] **Protocol Probe Artifacts** — JSON artifacts from **both** runners for all DCs (DC02, DC03, DC04) present in `evidence/`.
- [ ] **Maester Reports from Windows Runner** — All 4 report formats (`.html`, `.json`, `.md`, `-summary.md`) from Windows runner present.
- [ ] **Maester Reports from Linux Runner** — All 4 report formats from Linux runner present.
- [ ] **Preflight Results** — `preflight-*.json` artifact present.
- [ ] **Public Matrix Results** — `task-*-public-matrix-*.json` and `task-*-public-matrix-summary.json` present.
- [ ] **Evidence Index** — `EVIDENCE-INDEX.md` catalogues every file, its source runner, and the scenario it validates.
- [ ] **User Verification** — Evidence tar/zip inspected and explicitly confirmed by user as complete before upload.

### Common Failure Patterns to Reject

| Pattern | Rejection Reason |
|---|---|
| `az vm run-command invoke` used for test execution | Wrong PowerShell version (5.1), module scope issues, not certified |
| `Get-ADDefaultDomainPasswordPolicy not recognized` | Test still depends on RSAT/AD module instead of `System.DirectoryServices.Protocols` |
| `Select-Object -ExpandProperty OperatingSystem` / `Site` not found | Code expects AD module object schema instead of LDAP-returned attributes |
| Windows runner evidence missing from bundle | Incomplete certification package |
| Public E2E matrix skipped | Required component of full E2E certification |
| Only privileged user tested | Non-privileged path may expose hidden RSAT dependencies |
| Password escaping caused failures | `$` in passwords must be properly escaped in both bash and PowerShell |

---

## Examples

### Full deployment

```powershell
# Values are read from LabConfig.json automatically
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

- The runners are the only public ingress points. The domain controllers are private-only.
- The Windows runner is domain-joined to the primary forest and can use implicit
  root-forest credentials for RDP/WinRM-based execution.
- The Ubuntu runner has Kerberos authentication capability (via `kinit` and
  manual ticket cache) but is **not fully enrolled** via realmd/SSSD. The `sssd`
  service is inactive and domain users are not resolvable through standard Linux
  NSS. Use explicit credentials for all separate-forest rows.
- **SSH-based management** is the canonical transport for E2E validation. Two modes are supported:
  - **GSSAPI (Kerberos) SSH:** Required for implicit-credential rows. The Linux runner acquires a TGT via `kinit` and connects to the Windows runner using Kerberos authentication.
  - **Password-based SSH:** Works for explicit-credential rows only. Use `sshpass` with the Windows runner local admin password. Implicit-credential rows will fail because password auth does not provide a domain identity.
- **Note on SSH implicit credentials:** GSSAPI (Kerberos) SSH sessions **CAN** obtain ambient Kerberos tickets and validate implicit-credential rows. The `Get-MtAmbientDomainController` fallback in `Connect-MtAdTarget.ps1` activates in GSSAPI SSH sessions where `$env:LOGONSERVER` and `$env:USERDNSDOMAIN` are empty. Password-based SSH cannot validate implicit credentials.
- **Note on SSH explicit credentials:** The `Connect-Maester -ActiveDirectoryCredential` path is fully validated over both password-based and GSSAPI SSH. All explicit-credential rows pass.
- **Child domain deployment** requires a two-step process:
  1. Join the child DC VM to the parent domain (`Add-Computer`)
  2. Reboot, then promote to child domain (`Install-ADDSDomain`)
  3. Reboot again to complete the promotion
- Each Maester AD test run should still target exactly one endpoint at a time;
  this lab only automates the infrastructure.

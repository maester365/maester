# Active Directory E2E Testing Guide

This document describes how to deploy a reference Active Directory lab and validate Maester AD test changes end-to-end.

> **Note**: This guide is for Maester contributors developing or validating Active Directory tests. End users do not need to run this lab.

## Prerequisites

- Azure CLI (`az`) installed and authenticated
- Contributor access to an Azure resource group
- SSH key pair available locally
- PowerShell 7 (`pwsh`)

## Quick Start — Automated Lab Deployment

The `build/activeDirectory/azure-lab/` folder contains fully automated deployment scripts for Azure.

```powershell
# Deploy the complete multi-forest lab
./build/activeDirectory/azure-lab/Deploy-Lab.ps1 -ExecutorPublicIp '<YOUR_PUBLIC_IP>'
```

This creates:
- A VNet with three domain controllers (root forest, child domain, separate forest)
- Windows and Linux runners for cross-platform validation
- LDAPS/StartTLS certificates, DNS conditional forwarders, and WinRM endpoints

> **Note:** The deployment scripts default to a sample topology. Replace names, domains, and IP ranges with your own values via script parameters.

## Lab Topology

A reference lab for full E2E coverage needs:

| Role | Purpose |
|------|---------|
| Root DC | Root forest controller (e.g., `contoso.local`) |
| Child DC | Child domain controller (e.g., `child.contoso.local`) |
| Separate-forest DC | Cross-forest validation (e.g., `fabrikam.local`) |
| Windows runner | Domain-joined to root forest; supports implicit credentials |
| Linux runner | Kerberos-capable; explicit credentials only |

The root and child domains use the automatic two-way transitive intra-forest trust. No trust is configured between the root forest and the separate forest, so separate-forest runs require explicit credentials.

## Validation Workflow

All E2E validation must run **from the runners**, not directly on the DCs. DC-local execution produces valid results but does not exercise the full client-path topology.

### 1. Protocol Prerequisites

Before running AD tests, validate that the runner can reach and negotiate the required protocols for the chosen directory server:

| Protocol | Port | Notes |
|----------|------|-------|
| LDAP | TCP/389 | Plaintext LDAP (not for secure auth) |
| LDAPS | TCP/636 | TLS-wrapped LDAP |
| DNS | TCP/53 | Name resolution |
| SMB | TCP/445 | SYSVOL file access |
| WinRM HTTP | TCP/5985 | Windows remoting |
| WinRM HTTPS | TCP/5986 | Encrypted Windows remoting |

When using LDAPS / StartTLS and WinRM over HTTPS, ensure the runner trusts the server certificates.

### 2. Preflight Gate

```powershell
./build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1 -TargetName 'contoso.local'
```

Must pass before any E2E rows run. Validates DNS, certificate trust, StartTLS, runner posture, and banned-module absence.

### 3. Protocol Probe Matrix

```powershell
./build/activeDirectory/azure-lab/Invoke-ProtocolProbeMatrix.ps1
```

Low-level protocol validation covering:
- Basic-over-LDAPS success
- Basic-over-389 rejection
- StartTLS success/failure
- Implicit/explicit credential binds
- Cross-domain and cross-forest targeting

### 4. Public E2E Runner Matrix

```powershell
./build/activeDirectory/azure-lab/Invoke-PublicE2EMatrix.ps1
```

Full Maester test execution through the public path (`Connect-Maester -Service ActiveDirectory`).

Mandatory coverage includes:
- Root forest: implicit + explicit targeting × implicit + explicit credentials
- Child domain: explicit targeting × implicit + explicit credentials
- Separate forest: explicit targeting + explicit credentials

Each row runs in a **fresh PowerShell process** to prevent session contamination.

### 5. Single-Target Test Runner

```powershell
./build/activeDirectory/Run-ADTests-And-CopyReports.ps1 `
  -ConnectActiveDirectory -TargetName 'contoso.local'
```

Runs the AD test suite for one endpoint and copies report artifacts. Supports optional CSV and Excel export.

> **Single-target rule:** Run exactly one directory server per invocation. Do not loop over multiple targets in a single run.

## Interpreting Results

| Result | Meaning |
|--------|---------|
| `$true` | Test passed |
| `$false` | Security finding (expected on a minimal lab) |
| Error | Non-blocking execution issue (e.g., missing optional feature) |

A healthy baseline on a minimal lab typically sees ~220–230 of ~270 AD tests pass.

## Deployment Learnings

### Managed Identity Key Vault Permissions

When running `Deploy-Lab.ps1` with a managed identity, the identity needs the **Key Vault Secrets Officer** role on the target resource group to write generated secrets.

**Alternative:** Use `-SkipKeyVault` to bypass Key Vault and print credentials to the console (less secure, suitable for short-lived labs only).

### Outbound Internet Access

Windows Server VMs require outbound internet access to download AD DS feature payloads. Some Azure subscriptions disable default outbound access. Deploy a NAT Gateway and associate it with the lab subnet if needed.

### Azure VM Run Command Startup Delays

Azure VM Run Commands on Windows Server 2022 images can experience startup delays of 30–50 minutes before script execution begins. Increase `CompletionTimeoutMinutes` to at least 120 when calling `New-DomainController.ps1`.

### Child Domain Promotion

Child domain promotion (`Install-ADDSDomain`) requires the computer to have a valid Kerberos identity in the parent domain first. The two-step process:

1. Join the child DC VM to the parent domain (`Add-Computer`)
2. After reboot, promote to child domain (`Install-ADDSDomain`)

### Azure VM Run Command Stuck State

Azure VM Run Command can enter a permanent stuck state (`Conflict: Run command extension execution is in progress`). When this occurs, **SSH is the preferred alternative** for management and test execution.

### Credential Delegation Limitations

Azure VM Run Commands execute via the Azure VM Agent using WinRM with constrained delegation. This prevents certain Active Directory operations that require credential delegation, such as child domain promotion from a workgroup computer.

## Runner Authentication Notes

### Implicit Credentials

Implicit credential authentication works in any session with a valid domain identity:
- Interactive Windows sessions (RDP, WinRM)
- Azure VM Run Command as SYSTEM (uses computer account)
- **GSSAPI (Kerberos) SSH sessions**

Password-based SSH sessions as a local admin **cannot** obtain Kerberos tickets for ambient DC discovery. Use GSSAPI SSH for implicit-credential validation.

### Explicit Credentials

The `Connect-Maester -ActiveDirectoryCredential` path is fully validated over both password-based and GSSAPI SSH. All explicit-credential rows pass via SSH.

## Platform-Specific Transport Notes

### StartTLS on Linux

`System.DirectoryServices.Protocols.LdapConnection.StartTransportLayerSecurity()` is broken on Linux due to an upstream .NET bug (tested on .NET 8 and 10). OpenLDAP (`ldapsearch -ZZ`) works correctly on the same host.

| Test | Linux .NET | OpenLDAP |
|------|-----------|----------|
| LDAPS port 636 | PASS | N/A |
| StartTLS port 389 | FAIL | PASS |

**Remediation:** Use **LDAPS (port 636)** for all TLS validation on the Linux runner. Perform StartTLS validation exclusively from the **Windows runner**.

### PowerShell 5.1 Module Scope Issues

Always use **PowerShell 7 (`pwsh`)** for runner-based validation. PowerShell 5.1 has module scope issues that prevent Maester's internal LDAP functions from resolving correctly. Azure VM Run Command defaults to PS 5.1 and is not suitable for E2E certification.

## Cleanup

```powershell
./build/activeDirectory/azure-lab/Remove-Lab.ps1 `
  -TagName 'maester-lab-id' -TagValue '<YOUR_LAB_ID>'
```

## Files

| File | Purpose |
|------|---------|
| `Deploy-Lab.ps1` | Main orchestration entry point |
| `New-DomainController.ps1` | DC promotion, LDAPS cert creation, forest/domain setup |
| `New-LabVNet.ps1` | VNet, subnet, and NSG creation |
| `New-RunnerVm.ps1` | Windows and Ubuntu runner provisioning |
| `Configure-WinRM.ps1` | WinRM HTTPS + Negotiate configuration |
| `Enable-WindowsOpenSSH.ps1` | OpenSSH Server installation on Windows |
| `Install-PSWSMan.ps1` | Ubuntu preparation for PowerShell, smbclient, PSWSMan |
| `Test-LabPrerequisites.ps1` | Hard preflight gate |
| `Test-ADProtocolPrerequisites.ps1` | Protocol capability check |
| `Invoke-ProtocolProbeMatrix.ps1` | Protocol validation matrix |
| `Invoke-PublicE2EMatrix.ps1` | Public E2E runner matrix |
| `Invoke-LabVmRunCommand.ps1` | Enhanced VM Run Command wrapper |
| `Remove-Lab.ps1` | Lab teardown |
| `Run-ADTests-And-CopyReports.ps1` | Single-target test runner (in parent `build/activeDirectory/`) |

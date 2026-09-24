# Active Directory E2E Testing Guide

This document describes how to deploy a reference Azure Active Directory lab and validate Maester AD test changes end-to-end.

> **Note**: This guide is for Maester contributors developing or validating Active Directory tests. End users do not need to run this lab.

## Prerequisites

- Azure CLI (`az`) installed and authenticated
- Contributor access to an Azure resource group
- SSH key pair available locally
- PowerShell 7 (`pwsh`)

## Quick Start — Automated Lab Deployment

The `build/activeDirectory/azure-lab/` folder contains fully automated deployment scripts.

```powershell
# Deploy the complete multi-forest lab
./build/activeDirectory/azure-lab/Deploy-Lab.ps1 -ExecutorPublicIp '<YOUR_PUBLIC_IP>'
```

This creates:
- A VNet with three domain controllers (root forest, child domain, separate forest)
- Windows and Linux runners for cross-platform validation
- LDAPS/StartTLS certificates, DNS conditional forwarders, and WinRM endpoints

## Lab Topology

| Role | Example Name | Example Domain | Purpose |
|------|-------------|----------------|---------|
| Root DC | `DC01` | `contoso.local` | Root forest controller |
| Child DC | `DC02` | `child.contoso.local` | Child domain controller |
| Separate-forest DC | `DC03` | `fabrikam.local` | Cross-forest validation |
| Windows runner | `RunnerWin` | joined to root forest | Implicit-credential tests |
| Linux runner | `RunnerLinux` | Kerberos-capable | Explicit-credential tests |

> Replace example names with your own values in `Deploy-Lab.ps1` parameters.

## Validation Workflow

### 1. Preflight Gate

```powershell
./build/activeDirectory/azure-lab/Test-LabPrerequisites.ps1 -TargetName 'contoso.local'
```

Must pass before any E2E rows run. Validates DNS, certificate trust, StartTLS, and runner posture.

### 2. Protocol Probe Matrix

```powershell
./build/activeDirectory/azure-lab/Invoke-ProtocolProbeMatrix.ps1
```

Low-level protocol validation: Basic-over-LDAPS, StartTLS, implicit/explicit binds.

### 3. Public E2E Runner Matrix

```powershell
./build/activeDirectory/azure-lab/Invoke-PublicE2EMatrix.ps1
```

Full Maester test execution through the public path (`Connect-Maester -Service ActiveDirectory`).

### 4. Single-Target Test Runner

```powershell
./build/activeDirectory/Run-ADTests-And-CopyReports.ps1 `
  -ConnectActiveDirectory -TargetName 'contoso.local'
```

Runs the AD test suite for one endpoint and copies report artifacts.

## Interpreting Results

| Result | Meaning |
|--------|---------|
| `$true` | Test passed |
| `$false` | Security finding (expected on a minimal lab) |
| Error | Non-blocking execution issue (e.g., missing optional feature) |

A healthy baseline on a minimal lab typically sees ~220–230 of ~270 AD tests pass.

## Cleanup

```powershell
./build/activeDirectory/azure-lab/Remove-Lab.ps1 -TagName 'maester-lab-id' -TagValue '<YOUR_LAB_ID>'
```

## Troubleshooting

### SSH fails after DCPromo
Windows OpenSSH requires `AllowGroups` + `administrators_authorized_keys` after domain promotion. See `Enable-WindowsOpenSSH.ps1`.

### StartTLS on Linux
Known upstream .NET limitation on Linux. Use LDAPS (port 636) for TLS validation on Linux runners. See `build/activeDirectory/azure-lab/README.md` for details.

### PowerShell 5.1 module scope issues
Always use PowerShell 7 (`pwsh`) for runner-based validation. Azure VM Run Command defaults to PS 5.1 and is not suitable for E2E certification.

## Files

| File | Purpose |
|------|---------|
| `Deploy-Lab.ps1` | Main orchestration |
| `Test-LabPrerequisites.ps1` | Hard preflight gate |
| `Invoke-ProtocolProbeMatrix.ps1` | Protocol validation |
| `Invoke-PublicE2EMatrix.ps1` | Public E2E matrix |
| `Run-ADTests-And-CopyReports.ps1` | Single-target runner |
| `README.md` | Detailed lab automation docs |

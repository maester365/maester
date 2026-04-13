---
id: overview
title: Microsoft Defender for Endpoint Tests
sidebar_label: 🛡️ MDE Overview
description: Tests for Microsoft Defender for Endpoint configuration
---

# Microsoft Defender for Endpoint Tests

## Overview

The tests in this section verify that your Microsoft Defender for Endpoint (MDE) configuration follows security best practices. The tests cover three areas:

- **Antivirus Policy (AV)** - Validates Intune Settings Catalog policies for Microsoft Defender Antivirus, checking that key protection features are enabled and properly configured.
- **Global Configuration (GC)** - Validates tenant-wide Defender for Endpoint settings in the Microsoft Defender XDR portal. These are manual review tests since the settings are not available via Graph API.
- **Policy Design (PD)** - Validates that your MDE policies follow design best practices such as consistent naming, dedicated exclusion profiles, and staged deployment.

## Permissions

The automated antivirus tests require the following Microsoft Graph permissions:

- `DeviceManagementConfiguration.Read.All` — to read Intune configuration policies

## MDE Configuration

The MDE tests use configuration from the `GlobalSettings` section of `maester-config.json` to control compliance evaluation behavior. You can customize this in your `./Custom/maester-config.json` file.

```json
{
  "GlobalSettings": {
    "MdeConfig": {
      "ComplianceLogic": "AllPolicies",
      "PolicyFiltering": "OnlyAssigned"
    }
  }
}
```

### Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| `ComplianceLogic` | `"AllPolicies"` | How to evaluate compliance across multiple policies. `"AllPolicies"` means every matching policy must be compliant. `"AnyPolicy"` means at least one policy must be compliant. |
| `PolicyFiltering` | `"OnlyAssigned"` | Which policies to evaluate. `"OnlyAssigned"` evaluates only policies that have group assignments. `"All"` evaluates all matching policies regardless of assignment. |

### Manual Review Tests

Tests marked as **Manual Review** (all GC and PD tests, plus AV20 and AV25) cannot be automated via the Graph API. These tests are automatically skipped with a descriptive message explaining what to review and where to find the setting in the Microsoft Defender XDR portal. They are included for documentation and tracking purposes.

## Tests

| Test ID | Title | Type |
|---------|-------|------|
| [MDE.AV01](/docs/tests/MDE.AV01) | Archive Scanning should be enabled | Automated |
| [MDE.AV02](/docs/tests/MDE.AV02) | Behavior Monitoring should be enabled | Automated |
| [MDE.AV03](/docs/tests/MDE.AV03) | Cloud Protection should be enabled | Automated |
| [MDE.AV04](/docs/tests/MDE.AV04) | Email Scanning should be enabled | Automated |
| [MDE.AV05](/docs/tests/MDE.AV05) | Script Scanning should be enabled | Automated |
| [MDE.AV06](/docs/tests/MDE.AV06) | Real-time Monitoring should be enabled | Automated |
| [MDE.AV07](/docs/tests/MDE.AV07) | Full Scan Removable Drives should be enabled | Automated |
| [MDE.AV08](/docs/tests/MDE.AV08) | Full Scan Mapped Drives should be disabled | Automated |
| [MDE.AV09](/docs/tests/MDE.AV09) | Scanning Network Files should be enabled | Automated |
| [MDE.AV10](/docs/tests/MDE.AV10) | CPU Load Factor should be optimized | Automated |
| [MDE.AV11](/docs/tests/MDE.AV11) | Scan should be scheduled | Automated |
| [MDE.AV12](/docs/tests/MDE.AV12) | Quick Scan Time configuration is not required | Automated |
| [MDE.AV13](/docs/tests/MDE.AV13) | Signatures should be checked before scan | Automated |
| [MDE.AV14](/docs/tests/MDE.AV14) | Cloud Block Level should be High or higher | Automated |
| [MDE.AV15](/docs/tests/MDE.AV15) | Cloud Extended Timeout should be 30-50 seconds | Automated |
| [MDE.AV16](/docs/tests/MDE.AV16) | Signature Update Interval should be 1-4 hours | Automated |
| [MDE.AV17](/docs/tests/MDE.AV17) | PUA Protection should be enabled | Automated |
| [MDE.AV18](/docs/tests/MDE.AV18) | Network Protection should be enabled | Automated |
| [MDE.AV19](/docs/tests/MDE.AV19) | Local Admin Merge should be disabled | Automated |
| [MDE.AV20](/docs/tests/MDE.AV20) | Tamper Protection should be enabled tenant-wide | Manual |
| [MDE.AV21](/docs/tests/MDE.AV21) | Real-Time Scan Direction should cover both directions | Automated |
| [MDE.AV22](/docs/tests/MDE.AV22) | Cleaned Malware should be retained for 30+ days | Automated |
| [MDE.AV23](/docs/tests/MDE.AV23) | Catch-up Full Scan should be disabled | Automated |
| [MDE.AV24](/docs/tests/MDE.AV24) | Catch-up Quick Scan should be disabled | Automated |
| [MDE.AV25](/docs/tests/MDE.AV25) | Remediation Action should be set to Quarantine | Manual |
| [MDE.AV26](/docs/tests/MDE.AV26) | Sample Submission should send safe samples automatically | Automated |
| [MDE.GC01](/docs/tests/MDE.GC01) | Preview Features should be enabled organization-wide | Manual |
| [MDE.GC02](/docs/tests/MDE.GC02) | Tamper Protection should be enabled tenant-wide | Manual |
| [MDE.GC03](/docs/tests/MDE.GC03) | EDR in Block Mode should be enabled | Manual |
| [MDE.GC04](/docs/tests/MDE.GC04) | Automatically Resolve Alerts should be configured | Manual |
| [MDE.GC05](/docs/tests/MDE.GC05) | Allow or Block File capability should be enabled | Manual |
| [MDE.GC06](/docs/tests/MDE.GC06) | Hide Duplicate Device Records should be enabled | Manual |
| [MDE.GC07](/docs/tests/MDE.GC07) | Custom Network Indicators should be enabled | Manual |
| [MDE.GC08](/docs/tests/MDE.GC08) | Web Content Filtering should be enabled | Manual |
| [MDE.GC09](/docs/tests/MDE.GC09) | Device Discovery should be enabled | Manual |
| [MDE.GC10](/docs/tests/MDE.GC10) | Download Quarantined Files should be enabled | Manual |
| [MDE.GC11](/docs/tests/MDE.GC11) | Streamlined Connectivity should be enabled | Manual |
| [MDE.GC12](/docs/tests/MDE.GC12) | Streamlined Connectivity to Intune/DFC should be enabled | Manual |
| [MDE.GC13](/docs/tests/MDE.GC13) | Isolation Exclusion Rules should be disabled | Manual |
| [MDE.GC14](/docs/tests/MDE.GC14) | Deception capabilities should be evaluated | Manual |
| [MDE.GC15](/docs/tests/MDE.GC15) | Microsoft Intune Connection should be enabled | Manual |
| [MDE.GC16](/docs/tests/MDE.GC16) | Authenticated Telemetry should be reviewed | Manual |
| [MDE.PD01](/docs/tests/MDE.PD01) | Policy naming should follow consistent convention | Manual |
| [MDE.PD02](/docs/tests/MDE.PD02) | Exclusions should be in dedicated profiles | Manual |
| [MDE.PD03](/docs/tests/MDE.PD03) | Device profiles should be granular | Manual |
| [MDE.PD04](/docs/tests/MDE.PD04) | Staging buckets should be implemented | Manual |

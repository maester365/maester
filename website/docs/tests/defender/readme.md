---
id: overview
title: Microsoft Defender for Endpoint Tests
sidebar_label: 🛡️ MDE Overview
description: Tests for Microsoft Defender for Endpoint configuration
---

# Microsoft Defender for Endpoint Tests

## Overview

The tests in this section verify that your Microsoft Defender for Endpoint (MDE) antivirus configuration follows security best practices. The tests validate Intune Settings Catalog policies for Microsoft Defender Antivirus, checking that key protection features are enabled and properly configured.

## Permissions

The tests require the following Microsoft Graph permissions:

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

## Tests

| Test ID | Title |
|---------|-------|
| [MT.1123](/docs/tests/MT.1123) | Archive Scanning should be enabled |
| [MT.1124](/docs/tests/MT.1124) | Behavior Monitoring should be enabled |
| [MT.1125](/docs/tests/MT.1125) | Cloud Protection should be enabled |
| [MT.1126](/docs/tests/MT.1126) | Email Scanning should be enabled |
| [MT.1127](/docs/tests/MT.1127) | Script Scanning should be enabled |
| [MT.1128](/docs/tests/MT.1128) | Real-time Monitoring should be enabled |
| [MT.1129](/docs/tests/MT.1129) | Full Scan Removable Drives should be enabled |
| [MT.1130](/docs/tests/MT.1130) | Full Scan Mapped Drives should be disabled for performance |
| [MT.1131](/docs/tests/MT.1131) | Scanning Network Files should be enabled |
| [MT.1132](/docs/tests/MT.1132) | CPU Load Factor should be optimized (20-30%) |
| [MT.1133](/docs/tests/MT.1133) | Scan should be scheduled |
| [MT.1134](/docs/tests/MT.1134) | Quick Scan Time configuration is not required |
| [MT.1135](/docs/tests/MT.1135) | Signatures should be checked before scan |
| [MT.1136](/docs/tests/MT.1136) | Cloud Block Level should be High or higher |
| [MT.1137](/docs/tests/MT.1137) | Cloud Extended Timeout should be 30-50 seconds |
| [MT.1138](/docs/tests/MT.1138) | Signature Update Interval should be 1-4 hours |
| [MT.1139](/docs/tests/MT.1139) | PUA Protection should be enabled |
| [MT.1140](/docs/tests/MT.1140) | Network Protection should be enabled |
| [MT.1141](/docs/tests/MT.1141) | Local Admin Merge should be disabled |
| [MT.1142](/docs/tests/MT.1142) | Real-Time Scan Direction should cover both directions |
| [MT.1143](/docs/tests/MT.1143) | Cleaned Malware should be retained for at least 30 days |
| [MT.1144](/docs/tests/MT.1144) | Catch-up Full Scan should be disabled |
| [MT.1145](/docs/tests/MT.1145) | Catch-up Quick Scan should be disabled |
| [MT.1146](/docs/tests/MT.1146) | Sample Submission should send safe samples automatically |

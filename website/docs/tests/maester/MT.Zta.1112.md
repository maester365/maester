---
title: MT.Zta.1112 - Personal-device APP enforces wipe-on-uninstall / data backup blocked
description: "Beyond mere existence of an APP (covered by 1110/1111), this test verifies the policy actually enforces work-personal data separation: - 'dataBackupBlocked = true' (no iCloud/Google backup of corporate data) - 'appActionIfDeviceComplianceRequired' is ''wipe'' or ''block'' (not..."
slug: /tests/MT.Zta.1112
sidebar_class_name: hidden
---

# Personal-device APP enforces wipe-on-uninstall / data backup blocked

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.DeviceCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.DeviceCompensation.Tests.ps1) |

## Description

Beyond mere existence of an APP (covered by 1110/1111), this test verifies the policy actually enforces work-personal data separation:
- `dataBackupBlocked = true` (no iCloud/Google backup of corporate data)
- `appActionIfDeviceComplianceRequired` is `'wipe'` or `'block'` (not `'warn'`)

These two settings are what makes APP protect data on a personal device. Without them, MAM is window-dressing.
## How to fix

1. Edit the APP policy → Data protection settings.
2. Set "Backup org data to iTunes / iCloud / Google" to **Block**.
3. Under Conditional launch → Device conditions → "Maximum allowed device threat level" set to **Block** or **Wipe** when device becomes non-compliant.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
---
title: MT.Zta.1004 - Devices pillar fail count is below the warn threshold
description: "ZTA's **Devices pillar** covers Intune compliance, BitLocker / FileVault enforcement, OS-version posture, and conditional-access compliant-device requirements. A bulk failure (≥ 20 Devices tests Failed) usually indicates a missing compliance policy assignment or a stale grace ..."
slug: /tests/MT.Zta.1004
sidebar_class_name: hidden
---

# Devices pillar fail count is below the warn threshold

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.PillarFocus.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.PillarFocus.Tests.ps1) |

## Description

ZTA's **Devices pillar** covers Intune compliance, BitLocker / FileVault enforcement, OS-version posture, and conditional-access compliant-device requirements. A bulk failure (≥ 20 Devices tests Failed) usually indicates a missing compliance policy assignment or a stale grace period rather than per-device drift.
## How to fix

1. Intune → Devices → Compliance policies — verify a baseline policy is assigned to all platforms in scope.
2. Intune → Endpoint security → Disk encryption — confirm enforcement on Windows + macOS.
3. Conditional Access — verify "require compliant device" is enforced on the platform pillars.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
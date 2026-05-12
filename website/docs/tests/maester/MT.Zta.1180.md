---
title: MT.Zta.1180 - Top compliance failure reasons enumerated
description: "When ≥ 5 ZTA Devices-pillar tests are Failed, queries DuckDB 'Device' to enumerate the top reasons devices are non-compliant. ZTA flags non-compliance at policy level; this test surfaces the **most common per-device root causes** so the operator knows where to focus remediatio..."
slug: /tests/MT.Zta.1180
sidebar_class_name: hidden
---

# Top compliance failure reasons enumerated

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.DeviceCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.DeviceCompensation.Tests.ps1) |

## Description

When ≥ 5 ZTA Devices-pillar tests are Failed, queries DuckDB `Device` to enumerate the top reasons devices are non-compliant. ZTA flags non-compliance at policy level; this test surfaces the **most common per-device root causes** so the operator knows where to focus remediation effort.

Common categories: encryption not enforced, OS version too old, password policy not met, antivirus signature stale, managementAgent='unknown'.
## How to fix

1. Intune → Devices → Compliance → review the top reason group.
2. For each reason: either fix the underlying gap (e.g. push BitLocker policy) or relax the compliance rule if it was over-strict.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
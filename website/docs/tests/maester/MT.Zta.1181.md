---
title: MT.Zta.1181 - CA What-If: typical user is BLOCKED on a non-compliant device
description: "Triggered when ZTA ['24824'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24824.md) Failed (CA policies block access from noncompliant devices). Uses Maester's 'Test-MtConditionalAccessWhatIf' (BETA Graph API) to simulate a sa..."
slug: /tests/MT.Zta.1181
sidebar_class_name: hidden
---

# CA What-If: typical user is BLOCKED on a non-compliant device

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.DeviceCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.DeviceCompensation.Tests.ps1) |

## Description

Triggered when ZTA [`24824`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.24824.md) Failed (CA policies block access from noncompliant devices). Uses Maester's `Test-MtConditionalAccessWhatIf` (BETA Graph API) to simulate a sample non-privileged user signing in to Office 365 from a Windows browser flagged as **non-compliant**, and verifies the returned grant includes `block` OR `compliantDevice`.

What-If is more rigorous than reading policy state because it reflects the actual policy graph evaluation including exclusions, group memberships, and authentication-strength compositions.
## How to fix

1. Conditional Access → policy targeting Office 365 → ensure `Require device to be marked as compliant` is in the Grant block.
2. Or use `Block access` for non-compliant devices on a separate policy.
3. Re-run; the What-If output should change to `block` or grant containing `compliantDevice`.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
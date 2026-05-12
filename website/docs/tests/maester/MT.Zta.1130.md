---
title: MT.Zta.1130 - CA What-If: a normal user signing in to Office 365 is required to MFA
description: "Triggered when ZTA ['21784'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21784.md) (phish-resistant auth) or ['21801'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21801.md) ..."
slug: /tests/MT.Zta.1130
sidebar_class_name: hidden
---

# CA What-If: a normal user signing in to Office 365 is required to MFA

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.CaCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.CaCompensation.Tests.ps1) |

## Description

Triggered when ZTA [`21784`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21784.md) (phish-resistant auth) or [`21801`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21801.md) (strong auth methods configured) Failed. Picks a sample non-privileged Member user and runs `Test-MtConditionalAccessWhatIf` simulating an Office 365 sign-in from a browser. Asserts the returned grant requires MFA — either via `builtInControls -contains 'mfa'` OR via an `authenticationStrength` reference.

This is the rigorous check for "do we actually require MFA on a normal sign-in?" — independent of how many CA policies exist or how their exclusions compose.

**Sample selection** — break-glass accounts (per `GlobalSettings.EmergencyAccessAccounts`) and Entra Connect sync accounts (`Sync_*` UPN, members of "Directory Synchronization Accounts" / "On Premises Directory Sync Account" role) are excluded from the typical-user sample pool. Sync accounts intentionally bypass interactive MFA and are protected via a dedicated CA blocking sign-in from outside trusted named locations — that hardening is out of scope for "typical user MFA".
## How to fix

1. Conditional Access → New policy → target All users (exclude break-glass) → All cloud apps → Grant: Require MFA OR Require authentication strength.
2. Save as Report-only first; verify via this same What-If; then Enable.
3. Re-run; the simulation should return mfa or authenticationStrength.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
---
title: MT.Zta.1141 - WHfB uplift candidates — users without phish-resistant MFA who already have a corporate device
description: "Cross-references 'UserRegistrationDetails' (members without any phish-resistant method registered) with 'Device' ('trustType' in 'AzureAd' / 'ServerAd' / 'Workplace'). Surfaces users who **could be moved to Windows Hello for Business** because they already have a corporate-tru..."
slug: /tests/MT.Zta.1141
sidebar_class_name: hidden
---

# WHfB uplift candidates — users without phish-resistant MFA who already have a corporate device

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.MfaUplift.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.MfaUplift.Tests.ps1) |

## Description

Cross-references `UserRegistrationDetails` (members without any phish-resistant method registered) with `Device` (`trustType` in `AzureAd` / `ServerAd` / `Workplace`). Surfaces users who **could be moved to Windows Hello for Business** because they already have a corporate-trusted device — the highest-leverage MFA uplift path with no procurement and no shipping new tokens.

The phish-resistant classification comes from `Get-MtZtaAuthMethodSet -Bucket PhishResistant` (FIDO2, WHfB, X.509-with-PIN, device-bound passkeys).

The `Device.trustType` enum is the Graph-canonical set: `AzureAd` = Entra-joined, `ServerAd` = hybrid (on-prem AD + Entra), `Workplace` = workplace-joined for SSO. Hybrid-joined devices do NOT emit a free-text `"Hybrid Azure AD joined"` value — that's a portal display string. ZTA emits the raw enum.
## How to fix

1. For each candidate: open Entra ID → User → Authentication methods → register Windows Hello for Business.
2. Optionally, apply a registration-campaign authentication-strength policy targeted at this group.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
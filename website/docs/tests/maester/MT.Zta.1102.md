---
title: MT.Zta.1102 - GuestUnconstrained bucket has fewer than 25 entries
description: "The **GuestUnconstrained** cross-cut groups guest accounts that ZTA flagged as having weak external-collaboration controls — typically guests outside conditional-access scope, with no compliant device, or never used yet still enabled."
slug: /tests/MT.Zta.1102
sidebar_class_name: hidden
---

# GuestUnconstrained bucket has fewer than 25 entries

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.GuestPosture.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.GuestPosture.Tests.ps1) |

## Description

The **GuestUnconstrained** cross-cut groups guest accounts that ZTA flagged as having weak external-collaboration controls — typically guests outside conditional-access scope, with no compliant device, or never used yet still enabled.

A bucket with more than 25 entries indicates **systemic guest-lifecycle drift**, not isolated cases. Address policy first (CA exclusions, lifecycle workflows, access reviews) before per-guest cleanup.
## How to fix

1. Entra ID → External Identities → External collaboration settings — review guest invite restrictions.
2. Entra ID → Identity Governance → Access Reviews — ensure recurring reviews on guest membership.
3. Conditional Access — verify a guest-targeted policy enforces MFA + device compliance.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
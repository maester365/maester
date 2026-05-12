---
title: MT.Zta.1150 - Inactive guest accounts with active credentials
description: "Streams the ZTA 'User' table (where 'userType='Guest'' AND 'accountEnabled=true') and surfaces guests whose most-recent successful sign-in is older than 90 days. Each one is a potential phishing target."
slug: /tests/MT.Zta.1150
sidebar_class_name: hidden
---

# Inactive guest accounts with active credentials

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.LifecycleHygiene.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.LifecycleHygiene.Tests.ps1) |

## Description

Streams the ZTA `User` table (where `userType='Guest'` AND `accountEnabled=true`) and surfaces guests whose most-recent successful sign-in is older than 90 days. Each one is a potential phishing target.

ZTA [`21858`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21858.md) flags this category at policy level; MT.Zta.1150 enumerates the actual users so the operator can take action without leaving the report.
## How to fix

1. Entra ID → Identity Governance → Access Reviews — set up a recurring review on the guest user set.
2. Entra ID → External Identities → Lifecycle workflow — auto-disable inactive guests after 90 days of no sign-in.
3. For ad-hoc cleanup: disable each listed guest, then delete after a grace period.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
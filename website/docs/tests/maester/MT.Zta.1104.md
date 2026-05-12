---
title: MT.Zta.1104 - Stale-signin user count is below the warn threshold
description: "Counts users whose **most-recent successful sign-in is older than 90 days** via the ZTA 'SignIn' table. Stale users with active accounts are the easiest credential-theft entry point — disabling or removing them is high-leverage. Threshold: warn at 25."
slug: /tests/MT.Zta.1104
sidebar_class_name: hidden
---

# Stale-signin user count is below the warn threshold

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.DuckDbEnrichment.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.DuckDbEnrichment.Tests.ps1) |

## Description

Counts users whose **most-recent successful sign-in is older than 90 days** via the ZTA `SignIn` table. Stale users with active accounts are the easiest credential-theft entry point — disabling or removing them is high-leverage. Threshold: warn at 25.
## How to fix

1. Entra ID → Users → filter by ``signInActivity.lastSignInDateTime < 90 days``.
2. For each: confirm with the user's manager whether the account is still required.
3. Disable (preferred) or delete; for service accounts, rotate to managed identity / service principal with rotation.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
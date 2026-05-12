---
title: MT.Zta.1170 - Stale non-privileged users with active accounts
description: "Maester 'MT.1029' covers stale **privileged** users via PIM alerts. This gap-fill extends the check to **non-privileged** users — the population PIM alerts ignore but which still represent ~80%+ of typical tenant identity sprawl. Streams 'User' ⨝ anti-join with 'RoleAssignment..."
slug: /tests/MT.Zta.1170
sidebar_class_name: hidden
---

# Stale non-privileged users with active accounts

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.LifecycleHygiene.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.LifecycleHygiene.Tests.ps1) |

## Description

Maester `MT.1029` covers stale **privileged** users via PIM alerts. This gap-fill extends the check to **non-privileged** users — the population PIM alerts ignore but which still represent ~80%+ of typical tenant identity sprawl. Streams `User` ⨝ anti-join with `RoleAssignment` and filters to `accountEnabled=true` AND last-sign-in older than 90 days.

**Break-glass exclusion**: accounts listed in `GlobalSettings.EmergencyAccessAccounts` are excluded — break-glass accounts intentionally lack recent sign-ins.
## How to fix

1. Identity Governance → Access Reviews — recurring review on all-users, auto-disable on no response.
2. Lifecycle workflow → trigger join/leave/mover automation for HR-driven changes.
3. For one-time cleanup: bulk-disable the listed accounts, then delete after grace period.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
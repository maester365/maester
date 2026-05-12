---
title: MT.Zta.1203 - Every bucket entry has UPN, UserId, or test-level evidence
description: "Every entry in a ZTA-derived user bucket must carry at least one of: 'UserPrincipalName', 'UserId', or a non-empty 'Evidence' array. An entry with all three null/empty is unactionable — the operator can't pivot to Entra ID, a sign-in log, or even know which ZTA TestId surfaced..."
slug: /tests/MT.Zta.1203
sidebar_class_name: hidden
---

# Every bucket entry has UPN, UserId, or test-level evidence

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.UserBuckets.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.UserBuckets.Tests.ps1) |

## Description

Every entry in a ZTA-derived user bucket must carry at least one of: `UserPrincipalName`, `UserId`, or a non-empty `Evidence` array. An entry with all three null/empty is unactionable — the operator can't pivot to Entra ID, a sign-in log, or even know which ZTA TestId surfaced it. This catches regressions in user-extraction (UPN/GUID regex) or DuckDB enrichment.

The matrix below lists every populated bucket and the count of orphan entries (no UPN, no Id, no Evidence). The aggregate assertion fails only when any bucket has at least one orphan.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
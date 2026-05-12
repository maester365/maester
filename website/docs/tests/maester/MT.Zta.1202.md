---
title: MT.Zta.1202 - Across all buckets, Group sample size never exceeds pre-cap Count
description: "'Count' is the **pre-cap** total number of unique entities ZTA flagged for this category. 'Group' is the (capped) sample of up to 'MaxUsersPerCategory' entries. The sample size must never exceed the pre-cap total — a violation indicates a bucketing-logic bug in 'Group-MtZtaFla..."
slug: /tests/MT.Zta.1202
sidebar_class_name: hidden
---

# Across all buckets, Group sample size never exceeds pre-cap Count

| Severity | Source |
| --- | --- |
| Low | [`Test-MtZta.UserBuckets.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.UserBuckets.Tests.ps1) |

## Description

`Count` is the **pre-cap** total number of unique entities ZTA flagged for this category. `Group` is the (capped) sample of up to `MaxUsersPerCategory` entries. The sample size must never exceed the pre-cap total — a violation indicates a bucketing-logic bug in `Group-MtZtaFlaggedIdentity`.

The matrix below lists every populated bucket and whether its `MaxUsersPerCategory` cap was applied (sample size < pre-cap total). The assertion fails only when at least one bucket's Group is larger than its Count.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
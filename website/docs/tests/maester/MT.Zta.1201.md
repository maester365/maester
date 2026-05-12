---
title: MT.Zta.1201 - All populated buckets carry a non-empty Pillar
description: "Every populated bucket must carry a non-empty 'Pillar' value (Identity / Devices / Network / Data) so downstream reporting can route findings to the right pillar owner. A null 'Pillar' typically means a CategoryMappings rule was misconfigured (no 'MatchPillar' value) — usually..."
slug: /tests/MT.Zta.1201
sidebar_class_name: hidden
---

# All populated buckets carry a non-empty Pillar

| Severity | Source |
| --- | --- |
| Low | [`Test-MtZta.UserBuckets.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.UserBuckets.Tests.ps1) |

## Description

Every populated bucket must carry a non-empty `Pillar` value (Identity / Devices / Network / Data) so downstream reporting can route findings to the right pillar owner. A null `Pillar` typically means a CategoryMappings rule was misconfigured (no `MatchPillar` value) — usually a category that ended up in `Other`.

The assertion aggregates across ALL populated buckets: every row in the matrix below must show a non-empty Pillar; the test fails only when at least one bucket has a missing Pillar.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
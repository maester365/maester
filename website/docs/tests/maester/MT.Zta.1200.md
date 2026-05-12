---
title: MT.Zta.1200 - ZTA bucket family is populated
description: "Sentinel for the data-driven bucket family. Always emits one row so the family is visible in the report whether ZTA loaded or not, with a clear count of how many buckets were discovered."
slug: /tests/MT.Zta.1200
sidebar_class_name: hidden
---

# ZTA bucket family is populated

| Severity | Source |
| --- | --- |
| Low | [`Test-MtZta.UserBuckets.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.UserBuckets.Tests.ps1) |

## Description

Sentinel for the data-driven bucket family. Always emits one row so the family is visible in the report whether ZTA loaded or not, with a clear count of how many buckets were discovered.

`MT.Zta.1201` / `1202` / `1203` below evaluate quality dimensions across ALL populated buckets and render the per-bucket result as a matrix inside a single row each.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
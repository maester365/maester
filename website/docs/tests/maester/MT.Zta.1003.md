---
title: MT.Zta.1003 - No PrivilegedAccess findings flagged users above the bar
description: "The **PrivilegedAccess** cross-cut bucket aggregates ZTA findings about role assignments, PIM eligibility, and credential management — across all four pillars (Identity / Devices / Network / Data). When more than 10 unique entries land in this bucket, role hygiene is the most ..."
slug: /tests/MT.Zta.1003
sidebar_class_name: hidden
---

# No PrivilegedAccess findings flagged users above the bar

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.IdentityFocus.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.IdentityFocus.Tests.ps1) |

## Description

The **PrivilegedAccess** cross-cut bucket aggregates ZTA findings about role assignments, PIM eligibility, and credential management — across all four pillars (Identity / Devices / Network / Data). When more than 10 unique entries land in this bucket, role hygiene is the most cost-effective remediation lever.
## How to fix

1. Open Entra ID → Privileged Identity Management → Roles → Assignments.
2. For each entry below: confirm whether the assignment is permanent (should be PIM-eligible), unmanaged (no review), or expired-but-still-active.
3. Convert permanent role assignments to PIM-eligible with access reviews.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
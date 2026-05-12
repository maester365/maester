---
title: MT.Zta.1002 - Identity fail ratio stays below 0.5 (50% of evaluated tests)
description: "**Fail ratio = Failed / (Total - Skipped - Planned).** Skipped/Planned tests are excluded from the denominator so a fully-licensed pillar with 10 failures is comparable to an under-licensed pillar with 10 failures plus 50 skipped tests."
slug: /tests/MT.Zta.1002
sidebar_class_name: hidden
---

# Identity fail ratio stays below 0.5 (50% of evaluated tests)

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.IdentityFocus.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.IdentityFocus.Tests.ps1) |

## Description

**Fail ratio = Failed / (Total - Skipped - Planned).** Skipped/Planned tests are excluded from the denominator so a fully-licensed pillar with 10 failures is comparable to an under-licensed pillar with 10 failures plus 50 skipped tests.

A ratio above 0.5 means **more than half** of evaluated Identity tests failed — a strong signal that core Identity posture is broken, not just drifting on individual controls.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
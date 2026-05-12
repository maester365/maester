---
title: MT.Zta.1001 - Identity pillar fail count is below the warn threshold
description: "ZTA's **Identity pillar** covers authentication methods, conditional access, sign-in risk, PIM coverage, and external-collaboration exposure. When more than 30 Identity-pillar tests fail, the most likely cause is a **policy-level regression** (e.g. baseline CA policy disabled,..."
slug: /tests/MT.Zta.1001
sidebar_class_name: hidden
---

# Identity pillar fail count is below the warn threshold

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.IdentityFocus.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.IdentityFocus.Tests.ps1) |

## Description

ZTA's **Identity pillar** covers authentication methods, conditional access, sign-in risk, PIM coverage, and external-collaboration exposure. When more than 30 Identity-pillar tests fail, the most likely cause is a **policy-level regression** (e.g. baseline CA policy disabled, security defaults removed) rather than per-control drift. This test surfaces the bulk-failure signal before deeper per-bucket analysis.
## How to fix

1. Open the ZTA report and sort the Identity pillar Tests[] by TestId.
2. Compare against a known-good configuration baseline.
3. Restore policy-level controls FIRST, then re-run ZTA, then resume per-finding remediation.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
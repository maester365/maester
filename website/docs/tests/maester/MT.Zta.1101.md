---
title: MT.Zta.1101 - Identity fail ratio is high enough to warrant guest deep-dive
description: "**Gate test.** Runs only when the Identity-pillar fail ratio is **≥ 0.5** — the threshold below which deep-dive analysis isn't cost-effective. When this test is reported as Passed, it means ZTA found enough Identity failures that the per-bucket guest-posture tests below carry ..."
slug: /tests/MT.Zta.1101
sidebar_class_name: hidden
---

# Identity fail ratio is high enough to warrant guest deep-dive

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.GuestPosture.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.GuestPosture.Tests.ps1) |

## Description

**Gate test.** Runs only when the Identity-pillar fail ratio is **≥ 0.5** — the threshold below which deep-dive analysis isn't cost-effective. When this test is reported as Passed, it means ZTA found enough Identity failures that the per-bucket guest-posture tests below carry meaningful signal.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
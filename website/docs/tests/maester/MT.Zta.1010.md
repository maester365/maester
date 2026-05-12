---
title: MT.Zta.1010 - Bundle freshness is within tolerance (warn-but-proceed band)
description: "ZTA bundles older than 'FreshnessDays' (default 14) are considered stale. 'Test-MtZtaFreshness' warns and sets 'IsStale = $true' on the context; this test surfaces that flag explicitly so the operator can see the staleness without inspecting every test's detail panel. The most..."
slug: /tests/MT.Zta.1010
sidebar_class_name: hidden
---

# Bundle freshness is within tolerance (warn-but-proceed band)

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.OperatorDriftCheck.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.OperatorDriftCheck.Tests.ps1) |

## Description

ZTA bundles older than `FreshnessDays` (default 14) are considered stale. `Test-MtZtaFreshness` warns and sets `IsStale = $true` on the context; this test surfaces that flag explicitly so the operator can see the staleness without inspecting every test's detail panel. The most common cause of staleness is the resolver step falling back to last-good after the current ZTA stage failed.
## How to fix

1. Open the ZeroTrustAssessment stage logs from the current run.
2. Identify the failure root cause (auth, missing module, connectivity).
3. Re-run with `enableZtaExperimental=true` once the stage is healthy.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
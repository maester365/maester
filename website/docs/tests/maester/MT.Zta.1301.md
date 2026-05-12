---
title: MT.Zta.1301 - ZTA context is populated for this run
description: "End-to-end smoke test that the orchestration script's 'Import-MtZtaResult' call succeeded and '$script:MtZtaContext' is visible from the test runtime. When this fails, the ZTA wiring is broken — most likely the resolver step set 'ZTA_RESULTS_REF' to an empty path, or the Get-..."
slug: /tests/MT.Zta.1301
sidebar_class_name: hidden
---

# ZTA context is populated for this run

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.SeverityOverlay.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.SeverityOverlay.Tests.ps1) |

## Description

End-to-end smoke test that the orchestration script's `Import-MtZtaResult` call succeeded and `$script:MtZtaContext` is visible from the test runtime. When this fails, the ZTA wiring is broken — most likely the resolver step set `ZTA_RESULTS_REF` to an empty path, or the Get-MtZta self-heal couldn't find a usable bundle on disk.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
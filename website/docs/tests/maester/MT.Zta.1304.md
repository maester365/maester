---
title: MT.Zta.1304 - No escalation rule lowers severity (To is in {Medium,High,Critical})
description: "The severity overlay is a one-way escalation — it should never **lower** a test's severity. Allowed 'To' values are limited to {Medium, High, Critical}. A rule with 'To: Low' or 'To: Info' indicates a misconfiguration that would silently downgrade findings."
slug: /tests/MT.Zta.1304
sidebar_class_name: hidden
---

# No escalation rule lowers severity (To is in {Medium,High,Critical})

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.SeverityOverlay.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.SeverityOverlay.Tests.ps1) |

## Description

The severity overlay is a one-way escalation — it should never **lower** a test's severity. Allowed `To` values are limited to {Medium, High, Critical}. A rule with `To: Low` or `To: Info` indicates a misconfiguration that would silently downgrade findings.

(Note: the actual ladder check happens at runtime in `Test-MtZtaSeverityHigher` inside `Update-MtSeverityFromZta` — this test catches the misconfiguration at the rule shape level so the operator gets feedback before the pipeline runs.)
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
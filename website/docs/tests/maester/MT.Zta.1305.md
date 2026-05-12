---
title: MT.Zta.1305 - Severity overlay rule count + applied summary
description: "Smoke-tests the SeverityEscalationRules block by reporting how many rules exist and how many are wired with concrete selectors. This is mostly informational — failures of MT.Zta.1303 / 1304 already cover rule-shape correctness. This test exists to give the operator an at-a-gla..."
slug: /tests/MT.Zta.1305
sidebar_class_name: hidden
---

# Severity overlay rule count + applied summary

| Severity | Source |
| --- | --- |
| Low | [`Test-MtZta.OperatorDriftCheck.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.OperatorDriftCheck.Tests.ps1) |

## Description

Smoke-tests the SeverityEscalationRules block by reporting how many rules exist and how many are wired with concrete selectors. This is mostly informational — failures of MT.Zta.1303 / 1304 already cover rule-shape correctness. This test exists to give the operator an at-a-glance summary in the report tab.

(Note: the actual escalation mutation runs inside `Update-MtSeverityFromZta` which is invoked from `Invoke-Maester`. PR-E does not yet wire that call from the customer pipeline — it lands once the upstream Maester PR adds the `-ZtaResultsPath` parameter natively.)
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
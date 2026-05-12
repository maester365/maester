---
title: MT.Zta.1302 - ZtaSettings is wired into the context
description: "Operator opted into ZTA-aware behaviour by adding a 'ZtaSettings' block to 'maester-config.json' AND the orchestration script forwarded it to 'Import-MtZtaResult' via the '-ZtaSettings' parameter (or Get-MtZta's self-heal re-read it from '$env:MAESTER_ZTA_CONFIG_PATH'). When ..."
slug: /tests/MT.Zta.1302
sidebar_class_name: hidden
---

# ZtaSettings is wired into the context

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.SeverityOverlay.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.SeverityOverlay.Tests.ps1) |

## Description

Operator opted into ZTA-aware behaviour by adding a `ZtaSettings` block to `maester-config.json` AND the orchestration script forwarded it to `Import-MtZtaResult` via the `-ZtaSettings` parameter (or Get-MtZta's self-heal re-read it from `$env:MAESTER_ZTA_CONFIG_PATH`). When this is null, the data-driven and severity-overlay focus mechanisms (#3 and #4) silently degrade — the cmdlets exist but use vendor-neutral defaults.
## How to fix

Add a `ZtaSettings` block to `maester-config.json` (see plan Section B). At minimum: `CategoryMappings` for the data-driven mechanism and `SeverityEscalationRules` for the severity overlay.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
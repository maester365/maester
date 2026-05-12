---
title: MT.Zta.1103 - GuestUnconstrained bucket entries each carry evidence
description: "Every entry in the **GuestUnconstrained** bucket should carry at least one Evidence string explaining *why* it was flagged (which ZTA TestId surfaced it, or which DuckDB enrichment query). Entries with no evidence are unactionable and indicate a CategoryMappings or extraction ..."
slug: /tests/MT.Zta.1103
sidebar_class_name: hidden
---

# GuestUnconstrained bucket entries each carry evidence

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.GuestPosture.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.GuestPosture.Tests.ps1) |

## Description

Every entry in the **GuestUnconstrained** bucket should carry at least one Evidence string explaining *why* it was flagged (which ZTA TestId surfaced it, or which DuckDB enrichment query). Entries with no evidence are unactionable and indicate a CategoryMappings or extraction bug.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
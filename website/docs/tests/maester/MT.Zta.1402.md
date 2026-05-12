---
title: MT.Zta.1402 - Get-MtZtaRecommendedTag produces a non-empty tag list
description: "Verifies that 'Get-MtZtaRecommendedTag' (focus mechanism #1) emits a non-empty '[string[]]' of Maester tags derived from the loaded ZTA findings. When this is empty even though ZTA has failed tests, either the CategoryMappings block is missing matching rules or PillarTagMap is..."
slug: /tests/MT.Zta.1402
sidebar_class_name: hidden
---

# Get-MtZtaRecommendedTag produces a non-empty tag list

| Severity | Source |
| --- | --- |
| Low | [`Test-MtZta.OperatorDriftCheck.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.OperatorDriftCheck.Tests.ps1) |

## Description

Verifies that `Get-MtZtaRecommendedTag` (focus mechanism #1) emits a non-empty `[string[]]` of Maester tags derived from the loaded ZTA findings. When this is empty even though ZTA has failed tests, either the CategoryMappings block is missing matching rules or PillarTagMap is empty.
## How to fix

1. Confirm `ZtaSettings.CategoryMappings` covers the pillars that have failed tests (4 pillar-level rules + 2 cross-cuts is the recommended baseline).
2. Verify `ZtaSettings.PillarTagMap` lists the Maester-side tag aliases for each pillar.
3. Re-run with `WarningAction Continue` to surface the ">10% Other" coverage warning if many tests classify into Other.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
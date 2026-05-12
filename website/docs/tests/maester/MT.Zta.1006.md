---
title: MT.Zta.1006 - Data pillar fail count is below the warn threshold
description: "ZTA's **Data pillar** covers sensitivity-label coverage, DLP policy reach, and Purview-driven data classification. Bulk failures usually mean Purview isn't licensed/configured, OR labels exist but aren't published to the right scope."
slug: /tests/MT.Zta.1006
sidebar_class_name: hidden
---

# Data pillar fail count is below the warn threshold

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.PillarFocus.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.PillarFocus.Tests.ps1) |

## Description

ZTA's **Data pillar** covers sensitivity-label coverage, DLP policy reach, and Purview-driven data classification. Bulk failures usually mean Purview isn't licensed/configured, OR labels exist but aren't published to the right scope.
## How to fix

1. Purview portal → Information protection → Labels — verify at least one published label policy.
2. Purview → Data loss prevention → Policies — verify default DLP policies for Exchange + SharePoint + Teams.
3. Sensitivity label auto-labelling — verify it's enabled for E5/AIP-licensed users.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
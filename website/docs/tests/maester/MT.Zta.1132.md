---
title: MT.Zta.1132 - CA What-If: legacy-auth client is blocked
description: "Fires when the Identity pillar Failed count is ≥ 5 (proxy for \"tenant Identity posture is in active drift\"). Simulates a sign-in via legacy-auth ('exchangeActiveSync') and asserts the grant is 'block'."
slug: /tests/MT.Zta.1132
sidebar_class_name: hidden
---

# CA What-If: legacy-auth client is blocked

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.CaCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.CaCompensation.Tests.ps1) |

## Description

Fires when the Identity pillar Failed count is ≥ 5 (proxy for "tenant Identity posture is in active drift"). Simulates a sign-in via legacy-auth (`exchangeActiveSync`) and asserts the grant is `block`.

Many tenants have multiple "Block legacy auth" policies that compose oddly with exclusions. What-If is the only reliable way to verify the actual outcome.
## How to fix

1. Conditional Access → New / edit policy → target All users → Conditions → Client apps → check Exchange ActiveSync clients + Other clients.
2. Grant: Block access.
3. Re-run; the simulation should return block.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
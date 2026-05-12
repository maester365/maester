---
title: MT.Zta.1303 - Each severity escalation rule has a To severity and at least one selector
description: "Every 'SeverityEscalationRule' in 'ZtaSettings' must specify both: - 'To' — the target severity (Medium / High / Critical), - One of 'EscalateMaesterTagged' (tag selector) or 'EscalateMaesterTestId' (id wildcard selector)."
slug: /tests/MT.Zta.1303
sidebar_class_name: hidden
---

# Each severity escalation rule has a To severity and at least one selector

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.SeverityOverlay.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.SeverityOverlay.Tests.ps1) |

## Description

Every `SeverityEscalationRule` in `ZtaSettings` must specify both:
- `To` — the target severity (Medium / High / Critical),
- One of `EscalateMaesterTagged` (tag selector) or `EscalateMaesterTestId` (id wildcard selector).

Without `To`, the rule has no destination. Without a selector, the rule matches no tests. Either case makes the rule a no-op and indicates a configuration mistake.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
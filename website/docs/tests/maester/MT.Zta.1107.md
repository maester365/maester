---
title: MT.Zta.1107 - No permanent non-break-glass Global Administrator role assignments
description: "Lists **all** permanent (non-PIM-eligible) Global Administrator role assignments via the ZTA 'RoleAssignment' table. Each assignment is annotated as either:"
slug: /tests/MT.Zta.1107
sidebar_class_name: hidden
---

# No permanent non-break-glass Global Administrator role assignments

| Severity | Source |
| --- | --- |
| Critical | [`Test-MtZta.DuckDbEnrichment.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.DuckDbEnrichment.Tests.ps1) |

## Description

Lists **all** permanent (non-PIM-eligible) Global Administrator role assignments via the ZTA `RoleAssignment` table. Each assignment is annotated as either:

- `✓ break-glass` — declared in `maester-config.json` `GlobalSettings.EmergencyAccessAccounts`. Permanent grant is **expected** for these (compliant by config).
- `❌ permanent grant` — non-break-glass account with a permanent grant. **Critical finding** — convert to PIM-eligible.

The assertion fails only when there is at least one `❌` row.
## How to fix

How to remediate ❌ rows
1. Entra ID → Roles & administrators → Global administrator → list current assignments.
2. For each non-break-glass row: convert to PIM-eligible (Eligible assignments tab) and remove the permanent grant.
## Related Maester core tests

This test answers a question the policy-state family does NOT: *"is the grant standing, or just-in-time?"*. Run alongside:

- `MT.1032` — *Limited number of Global Admins are assigned* (Maester core). Caps the COUNT but does not distinguish permanent vs PIM-eligible.
- `CIS.M365.1.1.3` — *Between two and four global admins are designated*. Same: count-only.
- `CISA.MS.AAD.7.1` — *A minimum of two and a maximum of eight users SHALL be provisioned with Global Administrator*. Count-only.
- `CISA.MS.AAD.7.6` — *Activation of the Global Administrator role SHALL require approval*. Policy-side; does not check whether anyone bypasses activation via a standing grant.
- `CISA.MS.AAD.7.7` — *Eligible and Active highly privileged role assignments SHALL be monitored*. Closest in spirit; `MT.Zta.1107` provides the specific assertion ("zero permanent grants except break-glass").

**Joint reading**: passing `MT.1032` / `CIS.M365.1.1.3` with 2 GAs assigned is NOT sufficient if both are permanent grants and neither is declared break-glass. `MT.Zta.1107` catches that specific failure mode.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
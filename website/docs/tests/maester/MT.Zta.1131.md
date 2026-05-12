---
title: MT.Zta.1131 - CA What-If: a privileged user is required phish-resistant MFA
description: "Triggered when ZTA ['21782'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21782.md) (privileged accounts have phish-resistant methods registered) or ['21783'](https://github.com/microsoft/zerotrustassessment/blob/main/src/powe..."
slug: /tests/MT.Zta.1131
sidebar_class_name: hidden
---

# CA What-If: a privileged user is required phish-resistant MFA

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.CaCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.CaCompensation.Tests.ps1) |

## Description

Triggered when ZTA [`21782`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21782.md) (privileged accounts have phish-resistant methods registered) or [`21783`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21783.md) (privileged role CA enforces phish-resistant) Failed. Picks a sample privileged user (someone with at least one role assignment) and runs What-If for a sign-in to Office 365. The What-If grant must reference an `authenticationStrength` policy whose `allowedCombinations` are ALL within the phish-resistant set: `fido2`, `windowsHelloForBusiness`, `x509CertificateMultiFactor`.

**Why allowedCombinations and not displayName**: matching on the policy's display name is fragile — a custom auth strength named "Phishing-resistant MFA" with weak combinations would pass; localised display names would fail; an internally-named "FIDO2-only" strength would fail. Inspecting the actual permitted combinations is the only correct check. `x509CertificateSingleFactor` is single-factor cert auth and is explicitly **not** in the set (not MFA).

**Sample selection** — break-glass accounts (per `GlobalSettings.EmergencyAccessAccounts`) and Entra Connect sync accounts (members of the "Directory Synchronization Accounts" role, template ID `d29b2b05-8046-44ba-8758-1e26182fcf32`, with `Sync_*` UPN as a fallback heuristic) are excluded from the sample pool. Break-glass should be covered by a dedicated CA policy requiring phish-resistant MFA for that group only (see MT.1005 for break-glass exclusion correctness); sync accounts use cert-based auth + named-location restriction, not interactive MFA.

The What-If approach is critical here: many tenants have a "Require MFA for admins" policy that uses `builtInControls=mfa`, which accepts SMS/voice — i.e. NOT phish-resistant. Reading the static policy says "MFA required"; What-If reveals the strength is wrong.
## How to fix

1. Conditional Access → New policy → target privileged role membership (or admin-targeted group).
2. Grant: **Require authentication strength** → choose **Phishing-resistant MFA** (or a custom strength whose allowed combinations are all phish-resistant).
3. Re-run this test; the simulation should report `All phish-resistant? True`.
## Related Maester core tests

This test answers a question the policy-state family does NOT: *"does the actual policy graph enforce phish-resistant MFA for a real privileged user, after all CA policies compose?"*. It uses Graph What-If — the same evaluation Entra runs at sign-in time.

Policy-state counterparts:

- `CISA.MS.AAD.3.6` — *Phishing-resistant MFA SHALL be required for highly privileged roles*. Verifies a CA policy with phish-resistant grant exists; does not verify it applies to every priv user after exclusions / scopes compose.
- `CISA.MS.AAD.7.6` / `CISA.MS.AAD.7.8` — *GA role activation SHALL require approval / auth context*. Activation-side controls; orthogonal to live sign-in strength.

**Joint reading**:

- ``CISA.MS.AAD.3.6`` Passed + ``MT.Zta.1131`` Passed → policy exists AND it actually enforces at sign-in for the sampled priv user. ✅
- ``CISA.MS.AAD.3.6`` Passed + ``MT.Zta.1131`` Failed → there is a policy but the sampled priv user falls outside its scope (excludeUsers, excluded group, role-based-target with the wrong role IDs, etc.). **Audit the CA policy's user scope and exclusions** — the policy looks right on paper but doesn't apply where it should.
- ``CISA.MS.AAD.3.6`` Failed + ``MT.Zta.1131`` Passed → unusual; the named CISA-flavored policy isn't present, but some OTHER policy in scope happens to require phish-resistant for this user. Solid by luck, fragile by design.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
---
title: MT.Zta.1133 - Sign-ins not covered by Conditional Access stay below threshold
description: "Streams the ZTA 'SignIn' table and counts rows where 'conditionalAccessStatus' is 'notApplied' — i.e. the sign-in completed without ANY Conditional Access policy evaluating it. Asserts the ratio stays below the configured threshold (default 5%)."
slug: /tests/MT.Zta.1133
sidebar_class_name: hidden
---

# Sign-ins not covered by Conditional Access stay below threshold

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.CaCompensation.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.CaCompensation.Tests.ps1) |

## Description

Streams the ZTA `SignIn` table and counts rows where `conditionalAccessStatus`
is `notApplied` — i.e. the sign-in completed without ANY Conditional Access
policy evaluating it. Asserts the ratio stays below the configured threshold
(default 5%).

This is the **data-side** complement to MT.Zta.1130 / 1131 / 1132. Those
three call `Test-MtConditionalAccessWhatIf` to simulate what WOULD happen for
a sample user; 1133 reads the historical sign-in stream and answers what
actually DID happen — which user-app combinations escape the CA net in
practice.

Mirrors the "No CA applied" metric ZTA's own HTML report surfaces in its
`TenantInfo.OverviewCaMfaAllUsers` Sankey. Failing this test means a
non-trivial share of real sign-ins authenticated without CA gating —
typically guests, service principals, specific apps in "Other Cloud Apps",
or specific client-app types (e.g. legacy auth) escaping CA scope.
## How to fix

1. Open the sample table below; identify the top users with most
   `notApplied` sign-ins.
2. Entra ID → Sign-in logs → filter by one of those users → Conditional
   Access tab on a recent sign-in. The "Not applied" line shows which
   condition(s) excluded the sign-in from every policy in scope.
3. Common gap shapes:
   - **Guests** without a guest-targeted CA → add a B2B / external-user policy.
   - **Service principals** signing in → add a service-principal-targeted CA
     (Microsoft Entra ID P2 / Workload Identities Premium).
   - **Specific applications** excluded from CA scope → review per-app
     exclusions on top policies.
   - **Specific client app types** (e.g. exchangeActiveSync, other) →
     ensure a legacy-auth-block CA exists and matches the client type.
4. Add a catch-all "Block by default" CA targeting the gap surface. Save
   as Report-only, monitor for a week, then enable.
## Related Maester core tests

This is the **only data-side coverage check** in the entire Maester test corpus. The Maester core CA family inspects POLICY STATE (does a CA with the right grant exist?); none of them tell you whether the policies actually cover the sign-ins they were intended to cover.

Policy-state counterparts (all "is there a CA that ...?"):

- `MT.1001` — at least one CA configured with device compliance requirement.
- `MT.1003` / `MT.1004` — at least one CA targeting all cloud apps / all users.
- `MT.1005` — all CAs exclude at least one break-glass account.
- `MT.1006` / `MT.1007` / `MT.1008` — at least one CA requires MFA.
- `MT.1009` / `MT.1010` / `MT.1011` — block legacy auth / require auth context / secure named-location use.
- `CISA.MS.AAD.1.1` — legacy authentication SHALL be blocked.

**Joint reading**:

- Maester core CA tests Passed + ``MT.Zta.1133`` Passed → policies exist AND they actually cover ≥99% of sign-ins (default 1% bypass band). ✅
- Maester core CA tests Passed + ``MT.Zta.1133`` Failed → the right policies exist but a non-trivial share of sign-ins escape them. **Triage by looking at the user / app / clientApp top-offenders sample below.** Common root causes: guest sign-ins without a guest-targeted CA, service-principal sign-ins, app exclusions on top policies, legacy-auth client types not blocked.
- Maester core CA tests Failed + ``MT.Zta.1133`` Passed → unusual; the named CISA-flavored policies aren't present but some OTHER CA happens to cover sign-ins. Solid by luck, fragile by design — add the missing named policies before this changes.

A 0% bypass rate is the right target. Anything above that is gap surface waiting to be exploited.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
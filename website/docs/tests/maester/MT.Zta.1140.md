---
title: MT.Zta.1140 - Users without phish-resistant MFA registered
description: "Inspects 'UserRegistrationDetails.methodsRegistered' and surfaces members who have **zero** phish-resistant methods registered. Phish-resistant methods are tenant-invariant per Microsoft Graph (FIDO2, Windows Hello for Business, X.509 cert with PIN, device-bound passkeys). Any..."
slug: /tests/MT.Zta.1140
sidebar_class_name: hidden
---

# Users without phish-resistant MFA registered

| Severity | Source |
| --- | --- |
| High | [`Test-MtZta.MfaUplift.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.MfaUplift.Tests.ps1) |

## Description

Inspects `UserRegistrationDetails.methodsRegistered` and surfaces members who have **zero** phish-resistant methods registered. Phish-resistant methods are tenant-invariant per Microsoft Graph (FIDO2, Windows Hello for Business, X.509 cert with PIN, device-bound passkeys). Anyone without one is in either of two failure modes:

- **No MFA at all** (`methodsRegistered` is empty) — worst case; password is the only factor.
- **Phishable methods only** — the user has SMS / voice / email / Authenticator-push / TOTP (software or hardware) / `microsoftAuthenticatorPasswordless`. All of these can be relayed by an AiTM proxy or, in the passwordless case, collapse to "approve push on the same device that owns the session" under a stolen-device threat model.

The previous "single-factor = methodsRegistered.Count <= 1" heuristic conflated *no MFA* with *single FIDO2 key*, which is the opposite signal. The classification used here comes from `Get-MtZtaAuthMethodSet`, which is the single source of truth across MT.Zta.1140 / 1141 / 1142 / 1143.

Gap-fill triggered by ZTA [`21801`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21801.md) (strong auth methods configured) or [`21784`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21784.md) (phish-resistant auth) when Failed.
## How to fix

1. Entra ID → Security → Authentication methods → Registration campaign — push a phish-resistant registration nudge.
2. Conditional Access → enforce **Phishing-resistant MFA** authentication strength on privileged users first, then broaden.
3. Track week-over-week reduction in the `No MFA` and `Phishable-only` rows.
## Related Maester core tests

This test inspects **user-registration state** (have users actually registered phish-resistant methods?). The Maester core family inspects **policy state** (does the tenant configuration allow / enforce / disable specific methods?). Both layers must align for end-to-end protection.

Policy-state counterparts:

- `CISA.MS.AAD.3.1` / `CISA.MS.AAD.3.2` — *Phishing-resistant MFA SHALL be enforced for all users* (and the alternative-auth-strength fallback). Verifies a CA policy exists requiring phish-resistant MFA.
- `EIDSCA.AF01` — FIDO2 security key — State (enabled at tenant level).
- `EIDSCA.AF02` / `AF03` / `AF04` / `AF05` — FIDO2 self-service / attestation / key restriction / disallow restricted keys.
- `CISA.MS.AAD.3.5` — *Authentication methods SMS, Voice Call, and Email OTP SHALL be disabled*.
- `EIDSCA.AS04` — SMS for sign-in.
- `EIDSCA.AV01` — Voice call state.
- `MT.1063` — *App registration owners should have MFA registered* (overlapping intent, narrower scope: owners only).

**Joint reading**:

- ``CISA.MS.AAD.3.1`` Passed + ``MT.Zta.1140`` Failed → policy enforces phish-resistant, but users haven't migrated. At sign-in time the unprepared users will be hard-blocked or fall back via legacy escape paths. **Run a registration campaign — don't celebrate yet.**
- ``CISA.MS.AAD.3.1`` Failed + ``MT.Zta.1140`` Passed → users have phish-resistant methods registered, but the CA policy doesn't enforce. Attackers can social-engineer users back to a phishable method. **Add the CA policy now.**
- Both Passed → end-to-end phish-resistant for the population covered. ✅
- Both Failed → no policy AND no registrations. Highest-impact gap.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
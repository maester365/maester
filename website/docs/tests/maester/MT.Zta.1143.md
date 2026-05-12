---
title: MT.Zta.1143 - Privileged accounts on phishable methods (Critical gap)
description: "**Critical gap.** Joins 'UserRegistrationDetails' (users with phishable methods) with 'RoleAssignment' (any directory role) to find privileged users who could be phished. Privileged accounts on SMS / voice / email-OTP / TOTP / Authenticator-push MUST be uplifted to phish-resis..."
slug: /tests/MT.Zta.1143
sidebar_class_name: hidden
---

# Privileged accounts on phishable methods (Critical gap)

| Severity | Source |
| --- | --- |
| Critical | [`Test-MtZta.MfaUplift.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.MfaUplift.Tests.ps1) |

## Description

**Critical gap.** Joins `UserRegistrationDetails` (users with phishable methods) with `RoleAssignment` (any directory role) to find privileged users who could be phished. Privileged accounts on SMS / voice / email-OTP / TOTP / Authenticator-push MUST be uplifted to phish-resistant MFA before any other remediation work.

The phishable set comes from `Get-MtZtaAuthMethodSet -Bucket Phishable` (single source of truth shared with MT.Zta.1140 / 1142). Exact array membership against the closed Graph enum.

### Why a privileged user with BOTH strong AND weak methods still flags

The assertion fires whenever a privileged account has **any** phishable method *registered* — even if WHfB / FIDO2 / Passkey are also registered on the same account. This is intentional. A registered phishable method is an authentication PATH the attacker can drive the user toward (via AiTM phishing, fatigue push, SIM-swap on `mobilePhone`, SMTP-relay on `email`). Strong methods don't neutralise weak ones unless **Conditional Access enforces an authentication strength that excludes them at sign-in time**.

So this test surfaces the method *inventory* risk: "what methods CAN this admin use to sign in?" The compensating CA check lives in [`MT.Zta.1131`](https://maester.dev/docs/tests/MT.Zta.1131) (What-If returns a phish-resistant `authenticationStrength` for privileged users).

Break-glass accounts (declared in `GlobalSettings.EmergencyAccessAccounts`) and Entra Connect sync accounts (members of the Directory Synchronization Accounts role) are excluded — break-glass is covered by a dedicated CA + auth-strength path, sync uses cert-based auth and doesn't register interactive MFA methods.
## How to fix

**Treat as an incident** when 1143 + 1131 both Failed. When only 1143 Failed, treat as a defence-in-depth gap. For each user listed:
1. Block phishable methods on this account immediately via authentication-methods policy.
2. Force re-registration with FIDO2 / Passkey / Windows Hello for Business.
3. If MFA registration cannot complete in <24h: temporarily remove privileged role until re-registration is verified.
4. Verify CA `authenticationStrength` enforces phish-resistant for the role — see MT.Zta.1131.
## Related Maester core tests

This test inspects **registration inventory** (what phishable methods are registered on a priv account). It must be read alongside the policy-state and live-enforcement counterparts to avoid mis-triaging.

- ``CISA.MS.AAD.3.6`` — *Phishing-resistant MFA SHALL be required for highly privileged roles* (policy state).
- ``MT.Zta.1131`` — CA What-If for a sample priv user (live enforcement).
- ``MT.Zta.1140`` — All members without phish-resistant MFA registered (registration inventory, all-user scope; 1143 is the priv-user subset with the Critical severity overlay).

**Joint reading (1143 + 1131)**:

- **1143 Failed + 1131 Passed** → inventory is risky but live sign-in is gated. An authentication-methods policy change or CA misconfiguration could expose the weak path. **Defence-in-depth gap — reduce the inventory.**
- **1143 Failed + 1131 Failed** → both the inventory AND the live enforcement are weak. **Treat as an incident** — the priv user can sign in with a phishable method right now.
- **1143 Passed + 1131 Passed** → both clean. ✅
- **1143 Passed + 1131 Failed** → unusual; investigate the CA scope (the auth-strength policy may target an OU/role that excludes the admin in question).

**Three-way reading (1143 + 1131 + CISA.MS.AAD.3.6)**:

- All three Passed → end-to-end phish-resistant for priv. ✅
- ``CISA.MS.AAD.3.6`` Passed + 1131 Failed → policy exists but doesn't actually scope this priv user. CA exclusions or group-target mistake.
- ``CISA.MS.AAD.3.6`` Failed + 1131 Passed → no named CISA policy but some other CA happens to enforce. Add the named policy explicitly.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
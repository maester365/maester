---
title: MT.Zta.1160 - Application credentials older than 1 year
description: "Inspects 'Application.passwordCredentials' (a JSON-array column) and reports apps where any credential's 'endDateTime - startDateTime' exceeds 365 days. Long-lived secrets are the canonical phishing-resistant-bypass vector — short rotation cadence is the compensating control Z..."
slug: /tests/MT.Zta.1160
sidebar_class_name: hidden
---

# Application credentials older than 1 year

| Severity | Source |
| --- | --- |
| Critical | [`Test-MtZta.LifecycleHygiene.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.LifecycleHygiene.Tests.ps1) |

## Description

Inspects `Application.passwordCredentials` (a JSON-array column) and reports apps where any credential's `endDateTime - startDateTime` exceeds 365 days. Long-lived secrets are the canonical phishing-resistant-bypass vector — short rotation cadence is the compensating control ZTA [`21992`](https://github.com/microsoft/zerotrustassessment/blob/main/src/powershell/tests/Test-Assessment.21992.md) flags as missing.

Findings are split into two buckets:

- **Never-expiring secrets** (Critical) — credentials whose `endDateTime` is the year-9999 sentinel (or any lifetime > 50 years). These are higher severity than long-but-finite lifetimes because there is no remediation deadline at all; once leaked, the credential is valid forever. Treat each as an open incident.
- **Long-lived secrets** (Medium) — credentials with `endDateTime - startDateTime > 365 days` but a real expiry. Lower severity because they self-mitigate at expiry, but still drift well outside policy.
## How to fix

1. **Never-expiring secrets first** — Entra ID → Application registrations → filter by app — regenerate with a real expiry (≤ 90 days), then revoke the old one. Treat as an open incident; assume the secret is in scope of any past compromise.
2. Replace client secrets with **certificate** auth or **federated credentials** (workload identity federation) where possible — both eliminate long-lived secrets entirely.
3. Set an app-management policy enforcing max secret lifetime (90 days) tenant-wide.
## Related Maester core tests

This test is the **warn-band** for app-credential hygiene. The Maester core family has a stricter pass/fail bar (no static secrets at all) plus operational reminders that overlap in intent:

- ``MT.1057`` — *App registrations should no longer use secrets* (cert-only / federated-credentials). Strict pass/fail: any password credential fails. **Stricter target than 1160.**
- ``MT.1024.applicationCredentialExpiry`` — *Renew expiring application credentials*. Closest sibling — surfaces near-expiry credentials so they don't lapse silently. Operational reminder; not a strict gate.
- ``MT.1024.staleAppCreds`` — *Remove unused credentials from applications*. Catches credentials that exist but haven't been used recently. Orthogonal.
- ``MT.1077`` / ``MT.1078`` — *App registrations with privileged API permissions / directory roles should not have …* — additional risk overlays for high-impact apps.

**Joint reading**:

- ``MT.1057`` Failed + ``MT.Zta.1160`` Failed → secrets exist AND some are long-lived/never-expiring. **1160 lists the urgent ones to rotate first; MT.1057 is the long-term target (move to cert / federated identity).**
- ``MT.1057`` Failed + ``MT.Zta.1160`` Passed → secrets exist but all have reasonable lifetimes (≤ 1y). The cleanup is operational hygiene, not an incident.
- ``MT.1057`` Passed + ``MT.Zta.1160`` Passed → cert-only / federated tenant. ✅ ideal end-state.
- ``MT.1057`` Passed but ``MT.Zta.1160`` Failed should be impossible (1160 only fires when secrets exist); if it happens, file a bug.

Treat ``MT.Zta.1160`` Critical findings (year-9999 secrets) as incidents regardless of ``MT.1057`` status.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
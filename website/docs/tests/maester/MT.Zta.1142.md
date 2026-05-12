---
title: MT.Zta.1142 - Phishable-method users with mobile device registered
description: "Cross-references users registered with phishable methods (SMS / voice / email-OTP / TOTP / Authenticator-push) against 'Device' rows for iOS / Android. These users CAN be moved to Passkey or Windows Hello for Business — both phish-resistant — using a device they already have."
slug: /tests/MT.Zta.1142
sidebar_class_name: hidden
---

# Phishable-method users with mobile device registered

| Severity | Source |
| --- | --- |
| Medium | [`Test-MtZta.MfaUplift.Tests.ps1`](https://github.com/maester365/maester/blob/main/tests/Zta/Test-MtZta.MfaUplift.Tests.ps1) |

## Description

Cross-references users registered with phishable methods (SMS / voice / email-OTP / TOTP / Authenticator-push) against `Device` rows for iOS / Android. These users CAN be moved to Passkey or Windows Hello for Business — both phish-resistant — using a device they already have.

The phishable set comes from `Get-MtZtaAuthMethodSet -Bucket Phishable` (single source of truth across MT.Zta.1140 / 1142 / 1143). Exact array membership rather than substring regex — Graph emits these as a closed enum, so a substring match like `email` would falsely catch any future enum value containing the word "email".

The mobile-OS check uses the actual `Device.operatingSystem` values ZTA emits: `iOS`, `IPad` (capital-I capital-P — that's the literal column value, not "iPadOS"), and `Android`.

Break-glass and Entra Connect sync accounts are excluded — they do not appear on the typical-user uplift list.
## How to fix

1. Push Authenticator app via Intune to the listed devices.
2. Authentication-methods policy → require Passkey or Authenticator with phishing-resistant requirement.
3. Block phishable methods (SMS / voice / TOTP / Authenticator-push) once registration completes.
## Learn more

- [Zero Trust Assessment integration](/docs/zero-trust-assessment)
- [Zero Trust Assessment project](https://microsoft.github.io/zerotrustassessment/)
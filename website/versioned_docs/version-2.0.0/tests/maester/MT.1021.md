---
title: MT.1021 - Security Defaults are enabled
description: Security defaults make it easier to help protect your organization from identity-related attacks like password spray, replay, and phishing.
slug: /tests/MT.1021
sidebar_class_name: hidden
---

# Security Defaults are enabled

## Description

Security defaults make it easier to help protect your organization from identity-related attacks like password spray, replay, and phishing.

When enabled, the following controls are applied to your tenant:

- Requiring all users to register for multifactor authentication
- Requiring administrators to do multifactor authentication
- Requiring users to do multifactor authentication when necessary
- Blocking legacy authentication protocols
- Protecting privileged activities like access to the Azure portal


## How to fix

To enable security defaults:

- Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a [Security Administrator](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#security-administrator).
- Browse to **Identity** > **Overview** > **Properties**.
- Select **Manage security defaults**.
- Set **Security defaults** to **Enabled**.
- Select **Save**.

## Related links

- [Entra admin center - Security default settings](https://portal.azure.com/#view/Microsoft_AAD_ConditionalAccess/SecurityDefaults)
- [Security defaults in Microsoft Entra ID](https://learn.microsoft.com/entra/fundamentals/security-defaults)

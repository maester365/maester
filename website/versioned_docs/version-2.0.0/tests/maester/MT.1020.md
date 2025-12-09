---
title: MT.1020 - All Conditional Access policies are configured to exclude directory synchronization accounts or do not scope them
description: Exclude service accounts like the Microsoft Entra Connect Sync Account from conditional access policies
slug: /tests/MT.1020
sidebar_class_name: hidden
---

# All Conditional Access policies are configured to exclude directory synchronization accounts or do not scope them

## Description

- The directory synchronization accounts are used to synchronize the on-premises directory with Entra ID.
- These accounts should be excluded from all conditional access policies scoped to all cloud apps.
- Entra ID Connect does not support multifactor authentication.
- Restrict access with these accounts to trusted networks.

## How to fix

Exclude service accounts like the Microsoft Entra Connect Sync Account from conditional access policies that can block access such as requiring MFA.

## Learn more

- [Conditional Access policy: User exclusions](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-admin-mfa)

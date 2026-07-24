---
title: MT.1191 - Break-glass accounts are excluded from the Compliant Network Conditional Access policy
description: Every Conditional Access policy that enforces the Global Secure Access Compliant Network control should exclude the emergency access (break-glass) accounts.
slug: /tests/MT.1191
sidebar_class_name: hidden
---

# Break-glass accounts are excluded from the Compliant Network Conditional Access policy

## Description

A Conditional Access policy that enforces the Global Secure Access **Compliant Network** control blocks access when the session is not on a compliant network. If such a policy does not exclude the emergency access (break-glass) accounts, it can lock out the very accounts needed to recover the tenant during an outage or misconfiguration.

Every Compliant Network enforcement policy must therefore exclude all break-glass accounts (or the break-glass group). Emergency access accounts are read from the `EmergencyAccessAccounts` setting in `maester-config.json`.

## How to fix

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Conditional Access Administrator.
2. Browse to **Entra ID** > **Conditional Access** > **Policies** and open each flagged policy.
3. Under **Assignments** > **Users** > **Exclude**, add the emergency access accounts or the break-glass group.

## Learn more

- [Manage emergency access accounts in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)
- [Enable compliant network check with Conditional Access](https://learn.microsoft.com/entra/global-secure-access/how-to-compliant-network)

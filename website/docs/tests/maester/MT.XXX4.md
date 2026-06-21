---
title: MT.XXX4 - Entra Private Access applications are covered by a managed-device Conditional Access policy
description: Every Entra Private Access application should be protected by an enabled Conditional Access policy that requires a compliant or Microsoft Entra hybrid joined device.
slug: /tests/MT.XXX4
sidebar_class_name: hidden
---

# Entra Private Access applications are covered by a managed-device Conditional Access policy

## Description

Every Entra Private Access (and Quick Access) application should be protected by an enabled Conditional Access policy that requires a managed device - either by targeting the application directly or via All cloud apps. This ensures private applications are only reachable from managed endpoints.

A policy satisfies the requirement when it grants **Require device to be marked as compliant** (Intune compliant) or **Require Microsoft Entra hybrid joined device**.

This check evaluates application coverage only; it does not evaluate whether the policy applies to every user of the app.

## How to fix

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Conditional Access Administrator.
2. Browse to **Entra ID** > **Conditional Access** > **Policies**.
3. Create or edit an enabled policy that targets the affected Private Access applications (or **All cloud apps**) and, under **Grant**, requires a **compliant** or **Microsoft Entra hybrid joined** device.
4. Set **Enable policy** to **On** and select **Save**.

## Learn more

- [Apply Conditional Access to Private Access apps](https://learn.microsoft.com/entra/global-secure-access/how-to-target-resource-private-access-apps)
- [Require a compliant or hybrid joined device](https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-compliance)

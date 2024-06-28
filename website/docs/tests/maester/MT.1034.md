---
title: MT.1034 - Emergency access users should not be blocked
description: Checks if emergency access users are not blocked by any conditional access policy
slug: /tests/MT.1034
sidebar_class_name: hidden
---

# Emergency access users should not be blocked

:::info Important
The Conditional Access What If API is currently in public preview and is subject to change.
Maester tests written using this API may need to be updated as the API moves towards General Availability.

This check is only executed if you define the tag **CAWhatIf**
:::

## Description

Checks if emergency access users are not blocked by any conditional access policy using CA WhatIf.

## How to fix

Add all emergency access accounts as an exception to every conditional access policy.

## Learn more
  - [Manage emergency access accounts in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/security-emergency-access)

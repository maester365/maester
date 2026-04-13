---
title: MT.1033 - User should be blocked from using legacy authentication
description: Checks if a users is actually blocked from using legacy authentication
slug: /tests/MT.1033
sidebar_class_name: hidden
---

# User should be blocked from using legacy authentication

:::info Important
The Conditional Access What If API is currently in public preview and is subject to change.
Maester tests written using this API may need to be updated as the API moves towards General Availability.

This check is only executed if you define the tag **CAWhatIf**
:::

## Description

Checks if the tenant has at least one conditional access policy that actually blocks legacy authentication using CA WhatIf.

[Block legacy authentication with Microsoft Entra Conditional Access](https://learn.microsoft.com/en-us/entra/identity/conditional-access/block-legacy-authentication)

## How to fix

Create a conditional access policy that blocks legacy authentication for all users.

## Learn more
  - [Common Conditional Access policy: Block legacy authentication](https://learn.microsoft.com/en-us/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy)
  - [Conditional Access templates](https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-policy-common?tabs=secure-foundation#conditional-access-templates)

---
title: MT.1010 - At least one Conditional Access policy is configured to block legacy authentication for Exchange ActiveSync
description: Checks if the tenant has at least one conditional access policy that blocks legacy authentication for Exchange Active Sync authentication.
slug: /tests/MT.1010
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured to block legacy authentication for Exchange ActiveSync

## Description

Checks if the tenant has at least one conditional access policy that blocks legacy authentication for Exchange Active Sync authentication.

## How to fix

Create a conditional access policy that blocks legacy authentication for Exchange Active Sync for all users.

## Related links
- [Entra admin center - Conditional Access | Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Overview/fromNav/)
- [Conditional Access policy: Block legacy authentication](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-block-legacy)

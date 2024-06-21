---
title: MT.1001 - At least one Conditional Access policy is configured with device compliance
description: Device compliance conditional access policy can be used to require devices to be compliant with the tenant's security configuration.
slug: /tests/MT.1001
sidebar_class_name: hidden
---

# At least one Conditional Access policy is configured with device compliance

## Description

Device compliance conditional access policy can be used to require devices to be compliant with the tenant's security configuration.

## How to fix

Create a conditional access policy that requires devices to have device compliance.

Use this template and customize it to exclude MFA so that only device compliance is applied [Require a compliant device, Microsoft Entra hybrid joined device, or multi-factor authentication for all users](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-compliant-device).

## Related links
- [Entra admin center - Conditional Access | Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Overview/fromNav/)
- [Tenant App Management Policy - Microsoft Graph Reference](https://learn.microsoft.com/graph/api/resources/tenantappmanagementpolicy?view=graph-rest-1.0)

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

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Conditional Access Administrator.
2. Browse to **Protection** > **Conditional Access** > **Policies**.
3. Select **New policy**.
4. Give your policy a name.
5. Under **Assignments**, select **Users or workload identities**.
    - Under **Target resources** > **Resources (formerly cloud apps)** > **Include**, select **All resources (formerly 'All cloud apps')**.
6. Under **Access controls** > **Grant**.
    - Select **Require device to be marked as compliant** and **Require Microsoft Entra hybrid joined device**
    - **For multiple controls** select **Require one of the selected controls**.
    - Select **Select**
8. Confirm your settings and set **Enable policy** to **Enable**
9. Select **Create** to create to enable your policy.


Use this template and customize it to exclude MFA so that only device compliance is applied [Require a compliant device, Microsoft Entra hybrid joined device, or multi-factor authentication for all users](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-compliant-device).

## Related links
- [Entra admin center - Conditional Access | Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Overview/fromNav/)
- [Tenant App Management Policy - Microsoft Graph Reference](https://learn.microsoft.com/graph/api/resources/tenantappmanagementpolicy?view=graph-rest-1.0)

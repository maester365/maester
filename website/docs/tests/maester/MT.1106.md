---
title: MT.1106 - All Protected Actions Authentication Contexts should be referenced by a Conditional Access policy
description: This test checks if all Authentication Contexts used in Protected Actions are properly referenced in at least one active Conditional Access policy.
slug: /tests/MT.1106
sidebar_class_name: hidden
---

# Protected Actions Authentication Contexts should have Conditional Access policies

## Description

Protected Actions allow organizations to require step-up authentication for sensitive operations by assigning Authentication Contexts to those actions. However, if an Authentication Context is not referenced in any Conditional Access policy, the protected action is not effectively protected.

This test verifies that all Authentication Contexts used by Protected Actions are properly referenced in at least one active Conditional Access policy.

When a Protected Action has an Authentication Context assigned but that context is not referenced by any Conditional Access policy:

- Users will not be prompted for additional authentication when performing the protected action
- The security benefit of the Protected Action is lost
- The tenant may be exposed to unauthorized sensitive operations

## How to fix

If this test fails, you need to create or update Conditional Access policies to reference the Authentication Contexts used by your Protected Actions:

1. Navigate to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Go to **Protection** > **Conditional Access** > **Policies**
3. Create a new policy or edit an existing one
4. Under **Target resources** > **Authentication context**, select the Authentication Context(s) that need to be protected
5. Configure the appropriate grant controls (e.g., require multifactor authentication, require device to be marked as compliant, require approved client app)
6. Enable the policy and save

Alternatively, if the Protected Action no longer needs step-up authentication, you can remove the Authentication Context assignment from the Protected Action:

1. Navigate to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Go to **Identity** > **Roles & admins** > **Protected actions (Preview)**
3. Select the Protected Action
4. Remove or update the Authentication Context assignment

## Learn more

- [Protected actions in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/protected-actions-overview)
- [Conditional Access: Target resources](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-cloud-apps)
- [Authentication context in Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-cloud-apps#authentication-context)

## Related links

- [Entra admin center - Conditional Access Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Overview/fromNav/)
- [Entra admin center - Authentication contexts](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/AuthenticationContext)
- [Entra admin center - Protected actions](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/ProtectedActions)

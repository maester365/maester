---
title: MT.1067 - Authentication method policies should not reference non-existent groups.
description: This test checks if there are any authentication method policies that reference non-existent groups.
slug: /tests/MT.1067
sidebar_class_name: hidden
---

## Description

This test checks if there are any authentication method policies that reference non-existent groups.

Authentication method policies can reference groups in their includeTargets configuration. If a group is deleted but still referenced in an authentication method policy, it may cause the policy to not apply as expected or result in unexpected behavior.

This usually happens when a group is deleted but is still referenced in an authentication method policy configuration.

The test examines includeTargets for all authentication method configurations and validates that any group references are valid and the groups still exist in the tenant.

## How to fix

To fix this issue:

- Go to the [Microsoft Entra admin center](https://entra.microsoft.com)
- Navigate to **Protection** > **Authentication methods**
- Select the impacted authentication method
- In the **Include** section, remove the invalid group references
- If needed, add valid replacement groups
- Save the changes

## Learn more

- [Authentication methods in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-methods)
- [Manage authentication methods](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-methods-manage)
- [Authentication method policies](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-methods-activities)

## Related links

- [Entra admin center - Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity)
- [Entra admin center - Groups](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/AllGroups/menuId/AllGroups)

---
title: MT.1066 - Conditional Access policies should not reference non-existent users, groups, or roles.
description: This test checks if there are any Conditional Access policies that reference non-existent users, groups, or roles.
slug: /tests/MT.1066
sidebar_class_name: hidden
---

## Description

This test checks if there are any Conditional Access policies that reference non-existent users, groups, or roles.

This usually happens when a user, group, or role is deleted but is still referenced in a Conditional Access policy.

Non-existent objects in your policy can lead to unexpected gaps or behavior. This may result in Conditional Access policies not being applied to the intended users or the policy not functioning as expected.

The test examines:

- Include/exclude users in conditional access policies
- Include/exclude groups in conditional access policies
- Include/exclude roles in conditional access policies (both built-in and custom role definitions)

## How to fix

To fix this issue:

1. Naviagte to [Microsoft Entra admin center](https://entra.microsoft.com)
2. Navigate to **Entra ID** > **Conditional Access** > **Policies**
3. Open the impacted Conditional Access policy.
4. Remove the non-existent user, group, or role from the policy.
5. If the object is still needed, recreate it or replace it with a valid alternative.
6. Click **Save** to apply the changes.

## Learn more

- [Conditional Access: Users and groups](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-users-groups)
- [Manage Conditional Access policies](https://learn.microsoft.com/entra/identity/conditional-access/manage-conditional-access-policies)
- [Create custom roles in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/custom-create)

## Related links

- [Entra admin center - Conditional Access | Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Overview/fromNav/)
- [Entra admin center - Users](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers/menuId/AllUsers)
- [Entra admin center - Groups](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/AllGroups/menuId/AllGroups)
- [Entra admin center - Roles and administrators](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles/menuId/AllRoles)

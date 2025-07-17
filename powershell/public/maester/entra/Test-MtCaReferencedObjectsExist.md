# Conditional Access policies should not reference non-existent users, groups, or roles

This test checks if there are any Conditional Access policies that reference non-existent users, groups, or roles.

This usually happens when a user, group, or role is deleted but is still referenced in a Conditional Access policy.

Non-existent objects in your policy can lead to unexpected gaps or behavior. This may result in Conditional Access policies not being applied to the intended users or the policy not functioning as expected.

## How to fix

To fix this issue:

* Open the impacted Conditional Access policy.
* Remove the non-existent user, group, or role from the policy.
* If the object is still needed, recreate it or replace it with a valid alternative.
* Click Save to apply the changes.

## Learn more

* [Conditional Access: Users and groups](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-users-groups)
* [Manage Conditional Access policies](https://learn.microsoft.com/entra/identity/conditional-access/manage-conditional-access-policies)

<!--- Results --->
%TestResult%

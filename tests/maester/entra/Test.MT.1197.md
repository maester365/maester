Dynamic groups should not use the retiring `memberOf` rule operator.

Microsoft is ending the `memberOf` public preview on **November 3, 2026**. After that date,
dynamic groups that still use the operator stop updating and remain in their last known state.
Stale membership can leave outdated application access, Conditional Access targeting, Microsoft 365
access, or group-based licensing in place.

This test detects both `user.memberOf` and `device.memberOf` rules. It also reports source groups,
processing state, license assignments, and Conditional Access references to help prioritize
migration.

#### Remediation action:

1. In the **Microsoft Entra admin center**, open **Entra ID** > **Groups** >
   **[All groups][all-groups]**.
2. Open each reported group and record its current effective membership and downstream assignments.
3. Replace `memberOf` with supported attribute-based rules or convert the group to assigned
   membership.
4. Validate membership and every application, Conditional Access policy, Microsoft 365 resource, and
   license assignment that consumes the group.
5. Remove obsolete rules and groups. Pausing processing alone does not complete the migration.

#### Related links

* [Configure dynamic groups with memberOf and migrate before retirement][member-of-retirement]
* [Understand and manage dynamic group processing][dynamic-group-processing]

[all-groups]:
  https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/AllGroups
[member-of-retirement]:
  https://learn.microsoft.com/entra/identity/users/groups-dynamic-rule-member-of
[dynamic-group-processing]:
  https://learn.microsoft.com/entra/identity/users/manage-dynamic-group

<!--- Results --->
%TestResult%

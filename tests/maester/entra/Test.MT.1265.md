Dynamic groups should not stay in a failed rule processing state.

When Microsoft Entra ID can't evaluate the membership rule of a dynamic group, the group's processing
status becomes **Processing error** (`Failed` in Microsoft Graph). Until the error is fixed, the group's
membership does not follow its rule. In a lab test, a group in this state kept the members of its last
successful evaluation and did not add a new user that its previous rule matched, while a control group
that kept that rule added the user. Microsoft documents the same end state for groups that still use the
`memberOf` operator after its preview ends on November 3, 2026: they stop updating and remain in their
last known state. Conditional Access policies, group-based licensing and application access that target
such a group keep applying to its old membership, and users who should have joined it are left out.

In the same test, a rule that referenced an unsupported property was refused while processing was on,
but stored while processing was paused, in the portal and through Microsoft Graph. The error appeared
only after processing resumed.

This test reads the processing status of every dynamic group whose processing is turned on and lists the
groups whose status is `Failed`, with the error message, the Conditional Access policies that reference
them and their rule. Paused groups have no processing status and are not evaluated.

#### Remediation action:

1. In the **Microsoft Entra admin center**, open **Entra ID** > **Groups** >
   **[All groups][all-groups]**.
2. Open each reported group. Its overview page shows the processing status and an alert with the error.
3. Select **Dynamic membership rules**, correct the rule, and use **Validate rules** to check it
   against sample users or devices before you select **Save**.
4. Confirm that the processing status returns to **Update complete** and that the membership matches
   the rule.
5. Review the Conditional Access policies, license assignments and application access that use the
   group for users or devices that were left out or kept while processing failed.

#### Related links

* [Check the processing status for a rule][processing-status]
* [Validate rules for dynamic membership groups][validate-rules]
* [Understand and manage dynamic group processing][dynamic-group-processing]
* [Dynamic groups that use memberOf after the preview ends][member-of-retirement]
* [membershipRuleProcessingStatus resource type (beta)][status-resource]

[all-groups]:
  https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/AllGroups
[processing-status]:
  https://learn.microsoft.com/entra/identity/users/groups-create-rule#check-the-processing-status-for-a-rule
[validate-rules]:
  https://learn.microsoft.com/entra/identity/users/groups-dynamic-rule-validation
[dynamic-group-processing]:
  https://learn.microsoft.com/entra/identity/users/manage-dynamic-group
[member-of-retirement]:
  https://learn.microsoft.com/entra/identity/users/groups-dynamic-rule-member-of
[status-resource]:
  https://learn.microsoft.com/graph/api/resources/membershipruleprocessingstatus?view=graph-rest-beta

<!--- Results --->
%TestResult%

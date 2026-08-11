Dynamic group membership rules should use attributes with trusted and understood write paths.

Dynamic groups can grant access to applications, Microsoft 365 resources, Azure resources, and
Conditional Access policy scope. A user who can influence an attribute referenced by a membership
rule might be added to or removed from the group without an administrator changing group membership.

This test identifies rules that use potentially influenceable profile or identity properties and
custom attributes. A detected rule is marked **Investigate**, not Failed, because the rule alone
does not prove who can write the attribute or whether the group controls sensitive access.

Pattern and partial-match operators receive additional emphasis because they can match a broader
population than an exact comparison.

#### Remediation action:

1. In the **Microsoft Entra admin center**, open **Entra ID** > **Groups** >
   **[All groups][all-groups]**.
2. Open each reported group and review its dynamic membership rule and every resource assigned to
   it.
3. Identify every write path for the reported attribute, including user self-service, guest or home
   tenant influence, Entra roles, Microsoft Graph applications, provisioning services, Entra
   Connect, and on-premises directory permissions.
4. Replace influenceable attributes or broad pattern matching with an authoritative attribute and
   tightly restrict its writers. If the group controls sensitive access, validate its effective
   membership after changing the rule.

#### Related links

* [Manage rules for dynamic membership groups][dynamic-membership]
* [Dynamic group featuring an exploitable rule][tenable-indicator]
* [How to abuse Entra ID dynamic groups][argus-dynamic-groups]

[all-groups]:
  https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/AllGroups
[dynamic-membership]:
  https://learn.microsoft.com/entra/identity/users/groups-dynamic-membership
[tenable-indicator]:
  https://www.tenable.com/indicators/ioe/entra/DYNAMIC-GROUP-FEATURING-AN-EXPLOITABLE-RULE
[argus-dynamic-groups]:
  https://www.argusit.nl/en/blog/how-to-abuse-entra-id-dynamic-groups

<!--- Results --->
%TestResult%

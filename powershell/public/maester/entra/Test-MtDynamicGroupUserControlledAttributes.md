Dynamic group membership rules should use attributes that only trusted people and systems can
change.

Dynamic groups can grant access to applications, Microsoft 365 resources, Azure resources, and
Conditional Access policy scope. If a user or application can change an attribute used by a rule,
it might be able to add or remove an account without an administrator changing group membership.

This test identifies rules that use attributes whose values may be influenced by a user or changed
by a privileged writer. A detected rule is marked **Investigate**, not Failed, because the rule
alone does not prove who can write the attribute or whether the group controls sensitive access.

The results are separated into two risk levels:

* **Risky - user-influenceable attributes:** `city`, `companyName`, `country`, `department`,
  `displayName`, `givenName`, `jobTitle`, `mobile`, `otherMails`, `preferredLanguage`, `state`,
  `surname`, and `telephoneNumber`. A user might influence these profile or employment values
  directly or indirectly through HR, onboarding, profile-editing, or support workflows.
* **Low risk - application or administrator-controlled attributes:** `mail`, `mailNickname`,
  `proxyAddresses`, `userPrincipalName`, `extensionAttribute1-15`, and `extension_*`. These
  attributes are normally written by privileged applications, administrators, Exchange,
  provisioning systems, or directory synchronization.

These labels describe the likelihood of user influence, not the sensitivity of the group. A
low-risk attribute can still create a serious exposure if an untrusted or compromised writer can
change it.

Pattern and partial-match operators receive additional emphasis because they can match a broader
population than an exact comparison.

#### Remediation action:

1. In the **Microsoft Entra admin center**, open **Entra ID** > **Groups** >
   **[All groups][all-groups]**.
2. Open each reported group, select **Dynamic membership rules**, and compare the rule with the
   **Property** and **Rule** columns in the Maester result.
3. For **Risky** results, review user profile editing and every indirect workflow that accepts
   information from the user, including HR, onboarding, and support processes.
4. For **Low risk** results, review administrators, Exchange permissions, applications with
   permission to update users, provisioning systems, and Microsoft Entra Connect. For synchronized
   properties, also review permissions in the source Active Directory.
5. Determine what access the group grants. Start with the **Licenses** and **Conditional Access
   policies** columns in the Maester result, then check assignments to enterprise applications,
   Azure resources, Microsoft Teams, SharePoint, and other Microsoft 365 resources.
6. If an untrusted user or system can change the property and gain sensitive access, restrict who
   can change it or replace it with a property controlled by a trusted system. Prefer exact
   comparisons over broad pattern matching. Use assigned membership if no suitable property exists.
7. After changing the rule, verify the group's effective membership and assigned access.

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

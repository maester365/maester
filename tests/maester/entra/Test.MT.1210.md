Agent Users should not have privileged directory roles or membership in role-assignable groups.

An Agent User is an Entra user account created specifically for an AI agent to access services that require user-context authentication (e.g. Teams, Exchange mailboxes, SharePoint sites). Because Agent Users represent non-human workloads, they should never be assigned Entra directory roles or added to role-assignable security groups.

This check inspects all Agent Users in the tenant and verifies that they do not hold privileged directory roles, either active or PIM-eligible, or memberships in role-assignable groups. A PIM-eligible role counts because the Agent User can activate it at any time. Reading eligible assignments needs Microsoft Entra ID P2 or Governance; without it, only active assignments are checked and the result says so.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Users**.
2. Locate the reported Agent User using its **Object ID** or user principal name.
3. Check **Assigned roles** and remove any directory administrative roles. Check both the **Active assignments** and **Eligible assignments** tabs.
4. Check **Groups** and remove the user from any role-assignable security groups.
5. If the agent only requires access to specific mailboxes or SharePoint sites, configure direct resource-level permissions (e.g. Mailbox delegation or SharePoint site sharing) rather than tenant-wide administrator roles.

### Related links

* [Agent User resource overview][agent-user-resource]
* [Role-assignable groups in Microsoft Entra ID][role-assignable-groups]

[entra-admin-center]: https://entra.microsoft.com
[agent-user-resource]: https://learn.microsoft.com/graph/api/resources/agentuser?view=graph-rest-1.0
[role-assignable-groups]: https://learn.microsoft.com/entra/identity/role-based-access-control/groups-concept

<!--- Results --->
%TestResult%

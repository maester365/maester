Agent Users should have an existing Agent Identity.

An Agent User is the Entra user account paired with an Agent Identity. Some agents need this
second account to access systems that require a user account. The two accounts should share the
same lifecycle.

This check looks for Agent Users whose parent Agent Identity is missing. The account can be left
behind after the agent is deleted and may still have group memberships, licenses, or other access.
That makes it harder to tell why the account exists and whether it should still have access.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and go to **Entra ID** >
   **Users**. Search for the Agent User by its **Object ID** or user principal name. The
   report's parent value is an object ID; `identityParentId` is not a portal field.
2. Go to **Entra ID** > **Agents** > **Agent identities** and search for the parent Agent
   Identity object ID. Review its status, owners and sponsors, permissions, audit logs, and
   sign-in logs if it still exists.
3. If the Agent Identity is still needed, follow Microsoft's [restore guidance][agent-id-restore].
   If its blueprint or Blueprint Principal was deleted, restore that parent first when possible.
4. If the Agent User is no longer needed, review its group memberships, licenses, and access.
   Then delete it from **Entra ID** > **Users** or follow Microsoft's [Agent ID deletion
   guidance][agent-id-delete]. Deletion is soft by default, so the user can normally be restored
   for 30 days.

### Related links

* [Agent User resource][agent-user-list]
* [View and filter agent identities][agent-identity-list]
* [How to delete and restore agent identity objects][agent-id-delete]

[entra-admin-center]: https://entra.microsoft.com
[agent-user-list]: https://learn.microsoft.com/graph/api/agentuser-list?view=graph-rest-1.0
[agent-identity-list]:
  https://learn.microsoft.com/entra/agent-id/agent-lists
[agent-id-restore]:
  https://learn.microsoft.com/entra/agent-id/howto-delete-agent-identity
[agent-id-delete]: https://learn.microsoft.com/entra/agent-id/howto-delete-agent-identity

<!--- Results --->
%TestResult%

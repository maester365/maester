Enabled Agent Identities should have active sign-in activity within the last 180 days.

Agent Identities that remain enabled without active usage present a security risk. Inactive agents may retain assigned directory roles, OAuth permissions, or group memberships that are no longer monitored, making them prime targets for identity misuse or persistence.

This check queries sign-in activity reports across interactive, delegated, and application flows to identify enabled Agent Identities with no activity in the last 180 days.

#### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent identities**.
2. Search for the reported Agent Identity by its **Object ID** or display name.
3. Review its **Sign-in logs**, assigned **Permissions**, and owners.
4. If the agent is no longer needed:
   - Select **Disable** to prevent token exchange and authentication.
   - If decommissioning is approved, follow the [delete guidance][delete-agent-id] to remove the agent.
5. If the agent is needed on a seasonal or scheduled basis, document the business justification.

#### Related links

* [View and filter agent identities][agent-identity-list]
* [Disable agent identities][disable-agent-id]
* [How to delete agent identity objects][delete-agent-id]

[entra-admin-center]: https://entra.microsoft.com
[agent-identity-list]: https://learn.microsoft.com/entra/agent-id/agent-lists
[disable-agent-id]: https://learn.microsoft.com/entra/agent-id/disable-agent-identities
[delete-agent-id]: https://learn.microsoft.com/entra/agent-id/howto-delete-agent-identity

<!--- Results --->
%TestResult%

Enabled Agent Identities should show sign-in activity within the last 180 days.

An enabled Agent Identity that is no longer used can retain directory roles, OAuth permissions, and group memberships. Without active monitoring, these access rights create an unnecessary opportunity for misuse or persistence.

This check reviews interactive, delegated, and application sign-in activity. It reports enabled Agent Identities with no recorded activity during the last 180 days. It also reports an Agent Identity Blueprint when all of its child Agent Identities are inactive and the Blueprint still has a valid credential. This combination indicates that the Blueprint and its credentials may no longer be needed and should be reviewed.

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

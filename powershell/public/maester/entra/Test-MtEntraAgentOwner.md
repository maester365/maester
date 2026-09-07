Agent Identities, Blueprint Principals, and Blueprints should have at least one active, enabled owner.

Owners are the technical custodians responsible for an AI agent's configuration, credentials, and lifecycle. When an agent or blueprint has no assigned owners—or when all assigned owners are deleted or disabled user accounts—the agent becomes unmanaged, making it harder to review security access, investigate anomalies, or safely decommission stale resources.

This check audits all Agent Identities, Blueprint Principals, and Blueprints in the tenant to confirm they have at least one active and enabled owner.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent identities** (or **Agent blueprints**).
2. Search for the reported object by its **Object ID** or display name.
3. Under **Access**, select **Owners and sponsors**.
4. For a Blueprint, select the **Agent blueprint** or **Agent blueprint
   principal** tab for the reported object.
5. Select **Add** > **Add owner**, choose at least one active, responsible
   administrator or service manager, and select **Add**.
6. Review any existing owners and remove any disabled or former employee accounts.

### Related links

* [View and filter agent identities][agent-identity-list]
* [View and manage agent blueprints][manage-blueprints]
* [Manage owners and sponsors for Entra Agent ID][manage-owners]

[entra-admin-center]: https://entra.microsoft.com
[agent-identity-list]: https://learn.microsoft.com/entra/agent-id/agent-lists
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/identity-platform/manage-agent-blueprint
[manage-owners]: https://learn.microsoft.com/entra/agent-id/manage-owners-sponsors-agents

<!--- Results --->
%TestResult%

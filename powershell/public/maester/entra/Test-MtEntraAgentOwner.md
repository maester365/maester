Agent Identities, Blueprint Principals, and Blueprints should have at least one active, enabled owner.

Owners are the technical custodians responsible for an AI agent's configuration, credentials, and lifecycle. When an agent or blueprint has no assigned owners—or when all assigned owners are deleted or disabled user accounts—the agent becomes unmanaged, making it harder to review security access, investigate anomalies, or safely decommission stale resources.

This check audits all Agent Identities, Blueprint Principals, and Blueprints in the tenant to confirm they have at least one active and enabled owner.

#### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent identities** (or **Agent blueprints**).
2. Search for the reported object by its **Object ID** or display name.
3. Select **Owners** from the navigation menu and choose **Add owners**.
4. Assign at least one active, responsible administrator or service manager to the object.
5. Review any existing owners and remove any disabled or former employee accounts.

#### Related links

* [View and filter agent identities][agent-identity-list]
* [View and manage agent blueprints][manage-blueprints]
* [Manage owners in Microsoft Entra ID][manage-owners]

[entra-admin-center]: https://entra.microsoft.com
[agent-identity-list]: https://learn.microsoft.com/entra/agent-id/agent-lists
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[manage-owners]: https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-owner

<!--- Results --->
%TestResult%

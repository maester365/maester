Agent Identity Blueprints and Blueprint Principals should have assigned sponsors.

Sponsors provide business ownership and ongoing accountability for AI agents. While technical owners maintain configuration and authentication settings, sponsors justify why the agent exists, approve access scopes, and ensure the agent's activities remain aligned with organizational security policies.

This check audits all Agent Identity Blueprints and Blueprint Principals to verify that designated sponsors are assigned.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent blueprints**.
2. Search for the reported Blueprint or Blueprint Principal by its **Object ID** or display name.
3. Under **Access**, select **Owners and sponsors**.
4. Select the **Agent blueprint** or **Agent blueprint principal** tab for the reported object.
5. Select **Add** > **Add sponsor**, choose the appropriate business manager or
   department lead, and select **Add**.
6. Verify that the active sponsors are listed.

### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Manage sponsors for Entra Agent ID][manage-sponsors]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/identity-platform/manage-agent-blueprint
[manage-sponsors]: https://learn.microsoft.com/entra/agent-id/manage-owners-sponsors-agents

<!--- Results --->
%TestResult%

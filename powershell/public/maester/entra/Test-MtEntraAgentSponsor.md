Agent Identity Blueprints and Blueprint Principals should have assigned sponsors.

Sponsors provide business ownership and ongoing accountability for AI agents. While technical owners maintain configuration and authentication settings, sponsors justify why the agent exists, approve access scopes, and ensure the agent's activities remain aligned with organizational security policies.

This check audits all Agent Identity Blueprints and Blueprint Principals to verify that designated sponsors are assigned.

#### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent blueprints**.
2. Search for the reported Blueprint or Blueprint Principal by its **Object ID** or display name.
3. Select **Sponsors** from the left-hand navigation and click **Add sponsors**.
4. Select the appropriate business manager or department lead responsible for the AI workload.
5. Click **Save** and verify that active sponsors are listed.

#### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Manage sponsors for Entra Agent ID][manage-sponsors]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[manage-sponsors]: https://learn.microsoft.com/graph/api/agentidentityblueprint-list-sponsors

<!--- Results --->
%TestResult%

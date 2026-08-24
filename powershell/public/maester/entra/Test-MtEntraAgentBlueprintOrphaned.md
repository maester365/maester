Agent Identity Blueprint Principals should have an existing Blueprint.

An Agent Identity Blueprint defines how Agent Identities are created and managed. A Blueprint
Principal is the service principal created from that Blueprint in the tenant. If the Blueprint
is deleted but the Principal remains, the linked Agent Identities can fall outside the
Blueprint's management and lifecycle.

This check lists Blueprint Principals whose Blueprint no longer exists. Review each one before
deleting or restoring anything. The remaining Principal or Agent Identities may still have
permissions and access assignments.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and go to **Entra ID** >
   **Agents** > **Agent blueprints**.
2. Search for the reported **Blueprint App ID** and confirm whether the Blueprint was deleted
   or whether the Blueprint Principal is no longer required.
3. Review the reported Blueprint Principal and linked Agent Identity object IDs, including their
   owners, sponsors, permissions, audit logs, and sign-in logs.
4. If the agent is still required, follow Microsoft's restore guidance. If it is no longer
   required, disable the linked identities, review their access, and then remove the stale Agent
   ID objects in the order described by Microsoft.

### Related links

* [View and manage Agent Identity Blueprints][manage-blueprints]
* [How to delete and restore Agent Identity objects][delete-agent-id]
* [Agent Identity Blueprint resource][blueprint-resource]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[delete-agent-id]: https://learn.microsoft.com/entra/agent-id/howto-delete-agent-identity
[blueprint-resource]:
  https://learn.microsoft.com/graph/api/resources/agentidentityblueprint?view=graph-rest-1.0

<!--- Results --->
%TestResult%

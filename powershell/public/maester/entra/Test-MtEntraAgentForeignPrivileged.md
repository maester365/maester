Foreign or multi-tenant Agent Blueprints and Agent Identities should not hold privileged directory roles without review.

Multi-tenant Agent Blueprints originate in an external Microsoft Entra tenant. If a foreign Blueprint Principal or its child Agent Identities are granted a privileged directory role (like *Global Administrator*), a compromise of the blueprint or credentials in the external home tenant could compromise your local resources.

Foreign Blueprint Principals and their child Agent Identities must not be assigned privileged Microsoft Entra directory roles. Application permissions assigned to foreign Blueprint Principals should also be reviewed to confirm that they are necessary and follow least privilege. These application permissions are shown for review but do not cause the test to fail on their own.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent blueprints**.
2. Locate the reported foreign Blueprint Principal using its **Object ID** or display name.
3. Review its **Assigned roles** in **Entra ID** > **Roles & administrators**.
4. If privileged roles or unnecessary application permissions were assigned:
   - Remove directory role assignments and replace them with least-privilege delegated assignments.
   - Restrict application role assignments to only the specific resources required by the agent.
5. If the multi-tenant agent is untrusted or no longer required, remove the Blueprint Principal.

### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Manage multi-tenant applications in Microsoft Entra ID][multitenant-apps]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[multitenant-apps]: https://learn.microsoft.com/entra/identity/enterprise-apps/what-are-multitenant-apps

<!--- Results --->
%TestResult%

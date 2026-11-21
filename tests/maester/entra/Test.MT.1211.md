Agent Identity Blueprints should pass only explicitly selected delegated scopes and application roles to their child Agent Identities.

The `allAllowed` inheritance pattern gives every child Agent Identity all permissions granted to the Blueprint for a resource, without requiring separate consent. It also applies permissions granted to the Blueprint in the future. This can give existing and future Agent Identities broader access than intended and increases the impact of an unnecessary or high-risk permission assignment.

This test reports Agent Identity Blueprints that allow all delegated scopes or all application roles to be inherited. Each Blueprint should instead define only the permissions its child Agent Identities require.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent blueprints**.
2. Locate the reported Blueprint using its **Object ID** or display name.
3. Review its inheritable permissions configuration for the reported resource.
4. Replace the `allAllowed` pattern with an enumerated list: use **enumerated scopes** for delegated scope findings and **enumerated application roles** for application role findings. Include only the permissions agents require.
5. Re-consent affected Agent Identities if narrowing the inheritance pattern removes permissions they were using.

### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Configure inheritable permissions for agent identity blueprints][configure-inheritable-permissions]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[configure-inheritable-permissions]: https://learn.microsoft.com/entra/agent-id/configure-inheritable-permissions-blueprints

<!--- Results --->
%TestResult%

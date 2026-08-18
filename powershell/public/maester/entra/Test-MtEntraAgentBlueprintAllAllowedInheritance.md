Agent Identity Blueprints should not use the allAllowed inheritance pattern for delegated scopes or application roles.

An Agent Identity Blueprint's `inheritablePermissions` configuration controls which of the Blueprint's granted permissions on a resource are automatically inherited by every child Agent Identity, without additional consent. Setting a resource's inheritable scopes or roles to `allAllowed` inherits every permission currently granted to the Blueprint on that resource, and every permission granted to it later, to every existing and future child agent — a single future grant on the Blueprint becomes effective everywhere immediately.

This check inspects each Blueprint's `inheritablePermissions` collection and fails when any entry's `inheritableScopes.kind` or `inheritableRoles.kind` is `allAllowed`.

#### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent blueprints**.
2. Locate the reported Blueprint using its **Object ID** or display name.
3. Review its inheritable permissions configuration for the reported resource.
4. Replace the `allAllowed` pattern with **enumerated scopes**, listing only the specific permissions agents actually require.
5. Re-consent affected Agent Identities if narrowing the inheritance pattern removes permissions they were using.

#### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Configure inheritable permissions for agent identity blueprints][configure-inheritable-permissions]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[configure-inheritable-permissions]: https://learn.microsoft.com/entra/agent-id/configure-inheritable-permissions-blueprints

<!--- Results --->
%TestResult%

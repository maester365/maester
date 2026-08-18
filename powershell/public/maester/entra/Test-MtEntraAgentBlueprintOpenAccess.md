Agent Identity Blueprint Principals should require assignment for the application roles they expose.

An Agent Identity Blueprint Principal can declare application roles that other applications or agents request access to. When `appRoleAssignmentRequired` is `false` on the Blueprint Principal, Entra doesn't require an explicit assignment before issuing a token for those roles — any principal in the tenant can be issued a token for them.

This check inspects each Blueprint Principal that declares one or more application roles and fails when `appRoleAssignmentRequired` is `false`.

#### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Enterprise applications**.
2. Locate the reported Blueprint Principal using its **Object ID** or display name.
3. Under **Properties**, set **Assignment required?** to **Yes**.
4. Under **Users and groups** (or the equivalent app role assignment surface), explicitly assign the principals that should be able to obtain tokens for the exposed roles.

#### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Restrict your Microsoft Entra app to a set of users][restrict-app-users]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[restrict-app-users]: https://learn.microsoft.com/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users

<!--- Results --->
%TestResult%

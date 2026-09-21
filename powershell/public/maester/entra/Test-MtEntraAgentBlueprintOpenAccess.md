Agent Identity Blueprint Principals that expose application roles should require
an explicit assignment before another identity can use them.

Application roles control which applications or agents can access capabilities
provided by an Agent Identity Blueprint Principal. If assignment isn't required,
an identity in the tenant may receive a token for an enabled role without an
administrator explicitly granting it access. Requiring assignment ensures that
only approved identities can use those roles.

This test reports Agent Identity Blueprint Principals that expose at least one
enabled application role but don't require assignment. Disabled application
roles aren't included in the assessment.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Enterprise applications**.
2. Locate the reported Blueprint Principal using its **Object ID** or display name.
3. Under **Properties**, set **Assignment required?** to **Yes**.
4. Under **Users and groups** (or the equivalent app role assignment surface), explicitly assign the principals that should be able to obtain tokens for the exposed roles.

### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Restrict your Microsoft Entra app to a set of users][restrict-app-users]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[restrict-app-users]: https://learn.microsoft.com/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users

<!--- Results --->
%TestResult%

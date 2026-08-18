Agent Identities and Blueprint Principals should not be assigned privileged Entra directory roles.

Assigning Entra ID directory roles (such as *Global Administrator*, *Privileged Role Administrator*, *Application Administrator*, or *Agent ID Administrator*) directly to Agent Identities or Blueprint Principals allows an AI agent or service principal to modify directory objects, credentials, or tenant configurations.

AI agents should adhere strictly to the principle of least privilege. They should be granted scoped resource permissions or delegated application permissions rather than broad administrative directory roles.

This check queries all active directory role assignments to identify Agent Identities and Blueprint Principals holding directory roles.

#### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Roles & administrators**.
2. Search for the reported role name (e.g., *Global Administrator*, *Application Administrator*).
3. Under **Assignments**, locate the reported Agent Identity or Blueprint Principal.
4. Select the principal and click **Remove assignment**.
5. Replace administrative role assignments with specific, least-privileged API permissions or scoped resource permissions where necessary.

#### Related links

* [View and manage agent identities][manage-identities]
* [Least privileged roles by task in Microsoft Entra ID][least-privilege-roles]

[entra-admin-center]: https://entra.microsoft.com
[manage-identities]: https://learn.microsoft.com/entra/agent-id/agent-lists
[least-privilege-roles]: https://learn.microsoft.com/entra/identity/role-based-access-control/delegate-by-task

<!--- Results --->
%TestResult%

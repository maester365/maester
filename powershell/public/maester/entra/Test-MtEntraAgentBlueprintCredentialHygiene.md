Agent Identity Blueprints should not have expired, excessive, or overly long-lived client credentials.

Credentials on Agent Identity Blueprints are used for token exchange to authenticate all child Agent Identities. If a blueprint accumulates expired secrets, secrets valid for years without rotation, or an excessive number of active secrets, the risk of credential compromise and unmanaged persistence increases significantly.

This check inspects the credential metadata of all Agent Identity Blueprints in the tenant to identify expired secrets, credentials valid for more than 730 days (2 years), or blueprints with more than 2 active secrets.

#### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent blueprints**.
2. Locate the reported Blueprint using its **Object ID** or display name.
3. Select **Certificates & secrets** from the left-hand navigation.
4. Delete any **Expired** client secrets or certificates that are no longer in use.
5. If secrets have validity periods longer than your organization's maximum rotation window (recommended &le; 365–730 days), create a new secret and decommission the old one.
6. Prefer using **Federated credentials** or **Certificates** instead of shared client secrets wherever supported.

#### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Manage application credentials in Entra ID][manage-credentials]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[manage-credentials]: https://learn.microsoft.com/entra/identity/enterprise-apps/manage-certificates-for-federated-single-sign-on

<!--- Results --->
%TestResult%

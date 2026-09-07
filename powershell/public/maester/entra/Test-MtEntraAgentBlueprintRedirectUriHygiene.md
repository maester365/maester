Agent Identity Blueprints should use specific, secure redirect URIs.

During interactive consent, Microsoft Entra sends the consent result and optional state value to a redirect URI registered on the Blueprint. A wildcard can route that response to an unintended or attacker-controlled matching address. A plain HTTP address sends the response without transport encryption, allowing someone who can observe or alter network traffic to intercept or tamper with the consent result or state. HTTP loopback addresses are permitted for local development because the response stays on the same device instead of travelling across the network; they should not be used for deployed endpoints.

This test reports Agent Identity Blueprints with a wildcard redirect URI or a non-loopback HTTP redirect URI. Redirect URIs should identify a specific destination and use HTTPS unless they are loopback addresses used for local development.

### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent blueprints**.
2. Locate the reported Blueprint using its **Object ID** or display name.
3. Under **Authentication**, remove the reported redirect URI.
4. Replace it with a specific, `https`-only URI (or an `http://localhost`/loopback URI for local development only).

### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Redirect URI (reply URL) restrictions and limitations][redirect-uri-restrictions]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[redirect-uri-restrictions]: https://learn.microsoft.com/entra/identity-platform/reply-url

<!--- Results --->
%TestResult%

Agent Identity Blueprints should not use wildcard or plain-http redirect URIs.

A Blueprint's web redirect URIs are the destinations Entra will send authentication responses and tokens to. A wildcard redirect URI (containing `*`) lets a token be redirected to any host that matches the pattern, including one an attacker controls. A plain-http redirect URI that isn't a loopback address returns tokens over an unencrypted channel, where they can be intercepted in transit.

This check inspects each Blueprint's `web.redirectUris` and fails when any URI contains a wildcard or uses the `http` scheme without being a loopback address.

#### Remediation action:

1. Open the [Microsoft Entra admin center][entra-admin-center] and navigate to **Entra ID** > **Agents** > **Agent blueprints**.
2. Locate the reported Blueprint using its **Object ID** or display name.
3. Under **Authentication**, remove the reported redirect URI.
4. Replace it with a specific, `https`-only URI (or an `http://localhost`/loopback URI for local development only).

#### Related links

* [View and manage agent blueprints][manage-blueprints]
* [Redirect URI (reply URL) restrictions and limitations][redirect-uri-restrictions]

[entra-admin-center]: https://entra.microsoft.com
[manage-blueprints]: https://learn.microsoft.com/entra/agent-id/manage-agent-blueprint
[redirect-uri-restrictions]: https://learn.microsoft.com/entra/identity-platform/reply-url

<!--- Results --->
%TestResult%

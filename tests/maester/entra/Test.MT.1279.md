Should not have custom OIDC identity providers unlinked from any user flow

Entra External ID lets you configure custom OpenID Connect (OIDC) identity
providers under **identity/identityProviders**. Each custom OIDC identity
provider should be referenced by at least one user flow's
`onAuthenticationMethodLoadStart.identityProviders` collection. A custom
identity provider that is not linked to any user flow cannot be used to sign
in and typically indicates a leftover or abandoned configuration — unused
attack surface that should be reviewed and removed if no longer needed.

This test lists every custom OIDC identity provider that is not referenced
by any user flow so it can be reviewed and either linked to the correct user
flow(s) or removed. Built-in/social identity providers (e.g. Google, Email
OTP, Email with password) are excluded since they are not custom. Custom
SAML/WS-Fed identity providers are not exposed via this Graph API for Entra
External ID (CIAM) tenants and are therefore not evaluated by this test.

#### Remediation action

1. In the [Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CustomAuthenticationExtensionsMenuBlade/~/UserFlows), open **External Identities > All identity providers**.
2. Review each identity provider listed in the results below.
3. If the identity provider is still needed, add it to the appropriate user flow(s) as per the link below.
4. If the identity provider is no longer needed, delete it instead of linking it.

#### Related links

- [Configure a custom OIDC identity provider](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-custom-oidc-federation-customers)

<!--- Results --->
%TestResult%

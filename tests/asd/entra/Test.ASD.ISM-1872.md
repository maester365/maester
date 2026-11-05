Multi-factor authentication used for authenticating human users of online services is phishing-resistant (ISM-1872, Essential Eight Maturity Level Two).

Push notifications, one-time codes and SMS are relayed by adversary-in-the-middle phishing kits in real time. Passkeys (FIDO2), Windows Hello for Business and certificate-based authentication bind the sign-in to the site, so a proxied page gets nothing it can replay.

ASD's assessment guide applies this requirement to unprivileged and privileged users alike, and the ASD Blueprint for Secure Cloud meets it with one Conditional Access policy for all users and all resources that requires the **Phishing-resistant MFA** authentication strength. This test runs the same check as [CISA.MS.AAD.3.1](https://maester.dev/docs/tests/CISA.MS.AAD.3.1): an enabled policy that includes all users and all resources and specifies the built-in **Phishing-resistant MFA** strength, or a custom strength limited to Windows Hello for Business, passkeys (FIDO2) and certificate-based multifactor authentication. The check does not assess exclusions, narrowing conditions or alternative grant controls; review those separately to establish coverage for every sign-in.

#### Remediation action

1. Register phishing-resistant methods for your users: enable **Passkey (FIDO2)** and **Certificate-based authentication** under **Entra ID** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)**, and deploy Windows Hello for Business to managed devices.
2. In **Entra ID** > **[Conditional Access](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)**, create a policy with **Users** > **All users** (exclude your emergency access accounts), **Target resources** > **All resources**, and **Grant** > **Require authentication strength** > **Phishing-resistant MFA**.
3. Roll it out by group, starting with administrators, before you target all users.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [ASD Blueprint for Secure Cloud: Require strong auth](https://blueprint.asd.gov.au/configuration/entra-id/protection/conditional-access/policies/strong-authentication/)
* [Conditional Access authentication strength](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths)
* [Phishing-resistant passwordless authentication deployment](https://learn.microsoft.com/entra/identity/authentication/how-to-plan-prerequisites-phishing-resistant-passwordless-authentication)

<!--- Results --->
%TestResult%

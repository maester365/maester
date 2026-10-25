Multi-factor authentication used for authenticating users of online services is phishing-resistant (ISM-1872, Essential Eight Maturity Level Two).

Push notifications, one-time codes and SMS are relayed by adversary-in-the-middle phishing kits in real time. Passkeys (FIDO2), Windows Hello for Business and certificate-based authentication bind the sign-in to the site, so a proxied page gets nothing it can replay. This check looks for an enabled Conditional Access policy that targets all users and all cloud apps and grants access only with the built-in **Phishing-resistant MFA** authentication strength, or a custom strength limited to those methods.

#### Remediation action

1. Register phishing-resistant methods for your users: enable **Passkey (FIDO2)** and **Certificate-based authentication** under **Protection** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods)**, and deploy Windows Hello for Business to managed devices.
2. In **Protection** > **[Conditional Access](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)**, create a policy with **Users** > **All users** (exclude your emergency access accounts), **Target resources** > **All resources**, and **Grant** > **Require authentication strength** > **Phishing-resistant MFA**.
3. Roll it out by group, starting with administrators, before you target all users.

#### Related links

* [Essential Eight Maturity Model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Conditional Access authentication strength](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths)
* [Phishing-resistant passwordless authentication deployment](https://learn.microsoft.com/entra/identity/authentication/how-to-plan-prerequisites-phishing-resistant-passwordless-authentication)

<!--- Results --->
%TestResult%

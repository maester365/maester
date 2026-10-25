Multi-factor authentication is used to authenticate users to the organisation's online services (ISM-1504, Essential Eight Maturity Level One; ISM-0974 for unprivileged users at Maturity Level Two).

A password alone is defeated by phishing, password spray and credential stuffing. Requiring a second factor for every user on every cloud app is the first Essential Eight requirement for multi-factor authentication, and the baseline the phishing-resistant requirements of Maturity Level Two build on. This check looks for an enabled Conditional Access policy that targets all users and all cloud apps and grants access only with multi-factor authentication or an authentication strength that satisfies it.

#### Remediation action

1. In **Microsoft Entra admin center**, go to **Protection** > **[Conditional Access](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)** and create a policy.
2. **Users**: include **All users**; exclude only your emergency access accounts.
3. **Target resources**: **All resources (formerly 'All cloud apps')**.
4. **Grant**: **Require multifactor authentication**, or **Require authentication strength** with at least **Multifactor authentication**.
5. Enable the policy in **Report-only** first, then **On**.

#### Related links

* [Essential Eight Maturity Model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [ISM Guidelines for system access: Multi-factor authentication](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/ism/cyber-security-guidelines/guidelines-system-access)
* [Common Conditional Access policy: Require MFA for all users](https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-mfa-strength)

<!--- Results --->
%TestResult%

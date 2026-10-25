Multi-factor authentication is used to authenticate privileged users (ISM-1173, Essential Eight Maturity Level Two).

Administrator accounts are the accounts an attacker wants. A phished or sprayed administrator password without a second factor is a tenant takeover. This check looks for an enabled Conditional Access policy that targets all cloud apps, covers each of the fourteen highly privileged directory roles of Microsoft's 'Require MFA for administrators' template, listed below (by including all users, or by including each role without excluding it) and grants access only with multi-factor authentication or an authentication strength that satisfies it. Other roles that Microsoft Entra marks as privileged are not checked. Maturity Level Two also asks for the factor to be phishing-resistant; see ASD.ISM-1872.

#### Remediation action

1. In **Microsoft Entra admin center**, go to **Protection** > **[Conditional Access](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)** and create a policy.
2. **Users**: under **Include**, choose **Select users and groups** > **Directory roles** and select at least these roles: Global Administrator, Privileged Role Administrator, Privileged Authentication Administrator, Security Administrator, User Administrator, Application Administrator, Cloud Application Administrator, Conditional Access Administrator, Exchange Administrator, SharePoint Administrator, Authentication Administrator, Password Administrator, Billing Administrator and Helpdesk Administrator. Exclude only your emergency access accounts.
3. **Target resources**: **All resources (formerly 'All cloud apps')**.
4. **Grant**: **Require authentication strength** > **Phishing-resistant MFA**, or at least **Require multifactor authentication**.
5. Enable the policy in **Report-only** first, then **On**.

#### Related links

* [Essential Eight Maturity Model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Common Conditional Access policy: Require MFA for administrators](https://learn.microsoft.com/entra/identity/conditional-access/policy-old-require-mfa-admin)
* [Privileged roles and permissions in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/privileged-roles-permissions)

<!--- Results --->
%TestResult%

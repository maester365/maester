An enabled Conditional Access policy requires multifactor authentication for the privileged directory roles, in all cloud apps.

Administrator accounts can change identity, mail and security configuration for the whole organisation. A password alone is enough for an attacker who phished or sprayed it. Requiring MFA at sign-in for these roles makes a stolen password insufficient.

The test passes when one enabled policy lists every role in the set that the test checks: Application, Authentication, Billing, Cloud Application, Conditional Access, Exchange, Global, Helpdesk, Password, Privileged Authentication, Privileged Role, Security, SharePoint and User Administrator roles, plus Global Reader. Policies in report-only mode do not count. Keep emergency access accounts in the policy exclusions.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, select **Include** > **Select users and groups** > **Directory roles** and add every role listed above. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Grant**, select **Grant access** and **Require multifactor authentication** (or **Require authentication strength**).
6. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Require multifactor authentication for administrators with Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-policy-admin-mfa)
* [Plan a Conditional Access deployment](https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

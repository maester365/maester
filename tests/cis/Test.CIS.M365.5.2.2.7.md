An enabled Conditional Access policy responds to medium and high sign-in risk by requiring MFA every time or by blocking access.

Microsoft Entra ID Protection scores each sign-in on how likely it is that someone other than the account owner started it, for example an anonymous IP address, impossible travel or a leaked-credential match. A policy that responds to the score challenges or stops suspicious sign-ins even when the password is correct.

The policy needs Microsoft Entra ID P2 licences. Both medium and high must be selected. A policy that blocks access at those levels is stricter and is accepted.

User and group exclusions are not evaluated by this test. Application exclusions are also not evaluated when the policy targets all apps; verify exclusions are documented and reviewed annually. A condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Conditions** > **Sign-in risk**, set **Configure** to **Yes** and select **High** and **Medium**.
6. Under **Grant**, select **Grant access** and **Require multifactor authentication**.
7. Under **Session**, set **Sign-in frequency** to **Every time**.
8. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Configure risk policies in Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies)
* [Require MFA for risky sign-ins](https://learn.microsoft.com/entra/identity/conditional-access/policy-risk-based-sign-in)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.7](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

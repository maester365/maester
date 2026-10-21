An enabled Conditional Access policy responds to high user risk by requiring MFA and a password change, with sign-in frequency set to every time.

Microsoft Entra ID Protection marks an account as high risk when it has strong evidence that the credentials are leaked or the account is compromised. A policy that forces MFA and a password change lets the legitimate user recover automatically and gives the attacker nothing to reuse.

The policy needs Microsoft Entra ID P2 licences. Policies that also select medium or low risk are accepted, as long as high is included.

User and group exclusions are not evaluated by this test. Application exclusions are also not evaluated when the policy targets all apps; verify exclusions are documented and reviewed annually. A condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Conditions** > **User risk**, set **Configure** to **Yes** and select **High**.
6. Under **Grant**, select **Grant access**, then **Require multifactor authentication** and **Require password change**.
7. Under **Session**, set **Sign-in frequency** to **Every time**.
8. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Configure risk policies in Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies)
* [What is Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/overview-identity-protection)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

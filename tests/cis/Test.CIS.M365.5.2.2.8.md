An enabled Conditional Access policy blocks access when the sign-in risk is medium or high.

Asking a risky sign-in for MFA still leaves the account open to an attacker who can complete the prompt, for example by relaying it. Blocking sign-ins that Microsoft Entra ID Protection rates medium or high stops them before a session exists, and users with a genuine need are sent to the helpdesk.

The policy needs Microsoft Entra ID P2 licences. Expect some false positives, so involve the helpdesk before enabling it.

User and group exclusions are not evaluated by this test. Application exclusions are also not evaluated when the policy targets all apps; verify exclusions are documented and reviewed annually. A condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)** without exclusions.
5. Under **Conditions** > **Sign-in risk**, set **Configure** to **Yes** and select **High** and **Medium**.
6. Under **Grant**, select **Block access**.
7. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Configure risk policies in Microsoft Entra ID Protection](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies)
* [Risk-based access policies](https://learn.microsoft.com/entra/id-protection/concept-identity-protection-policies)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.8](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

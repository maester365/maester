An enabled Conditional Access policy requires all users to sign in again after at most seven days.

Without a limit, a session can stay valid for a very long time, and a refresh token that is stolen keeps working until the user next changes password. Periodic reauthentication forces a new sign-in, and a new MFA challenge, at a predictable interval, which caps how long a stolen session is useful.

The policy must apply to all users and all cloud apps, set the frequency to 7 days or less (or every time) and be enabled. Short intervals add prompts for users, so pick the longest interval that your risk appetite allows.

User and group exclusions are not evaluated by this test. Application exclusions are also not evaluated when the policy targets all apps; verify exclusions are documented and reviewed annually. A condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Session**, select **Sign-in frequency**, choose **Periodic reauthentication** and enter 7 days or less (or choose **Every time**).
6. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Configure adaptive session lifetime policies](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-session-lifetime)
* [Conditional Access: Session controls](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-session)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.13](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

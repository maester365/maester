An enabled Conditional Access policy sets a short sign-in frequency and turns off persistent browser sessions for the administrative roles.

A session token that stays valid for days or survives a browser restart can be stolen and replayed on another machine. Administrators hold the most valuable sessions, so shortening how long a session lasts, and not keeping it after the browser closes, limits how long a stolen token is useful.

The policy must apply to the same set of administrative roles as the MFA test, cover all cloud apps, set a sign-in frequency of 4 hours or less (or every time), set persistent browser session to **Never persistent** and be enabled.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, select **Directory roles** and add the administrative roles. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Session**, select **Sign-in frequency** and set it to **Periodic reauthentication** of 4 hours or less, or **Every time**.
6. Under **Session**, select **Persistent browser session** and choose **Never persistent**.
7. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Configure adaptive session lifetime policies](https://learn.microsoft.com/entra/identity/conditional-access/howto-conditional-access-session-lifetime)
* [Conditional Access: Session controls](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-session)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

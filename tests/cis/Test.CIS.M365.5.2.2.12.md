An enabled Conditional Access policy blocks the device code authentication flow for all users and all cloud apps.

In device code phishing, an attacker starts a device code sign-in and tricks the victim into entering the code on the genuine Microsoft sign-in page. The victim completes MFA and the attacker receives valid tokens. The flow exists for devices without a keyboard, which most organisations do not use.

Blocking the flow removes the technique. A device filter or other narrowing condition is reported by this check. User and group exclusions are not evaluated, and application exclusions are not evaluated when the policy targets all apps; document and review such exclusions separately.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Conditions** > **Authentication flows**, set **Configure** to **Yes** and select **Device code flow**.
6. Under **Grant**, select **Block access**.
7. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Block authentication flows with Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/policy-block-authentication-flows)
* [Conditional Access: authentication flows](https://learn.microsoft.com/entra/identity/conditional-access/concept-authentication-flows)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.12](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

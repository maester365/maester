An enabled Conditional Access policy blocks the authentication transfer flow for all users and all cloud apps.

Authentication transfer lets a signed-in session on one device start a session on another device, for example from a desktop browser to a mobile app. The second device inherits the trust of the first without its own sign-in, which attackers can abuse by getting a victim to scan a QR code.

Blocking the flow forces every device to sign in on its own and so to meet its own Conditional Access requirements.

Only emergency access accounts listed in [EmergencyAccessAccounts](https://maester.dev/docs/configuration/emergency-access-accounts) are accepted as exclusions, and a condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Conditions** > **Authentication flows**, set **Configure** to **Yes** and select **Authentication transfer**.
6. Under **Grant**, select **Block access**.
7. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Block authentication flows with Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/policy-block-authentication-flows)
* [Conditional Access: authentication flows](https://learn.microsoft.com/entra/identity/conditional-access/concept-authentication-flows)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.17](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

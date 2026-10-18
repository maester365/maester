An enabled Conditional Access policy requires the phishing-resistant MFA authentication strength for the administrative roles.

Push notifications, SMS and one-time codes can be relayed by an adversary-in-the-middle phishing site. Phishing-resistant methods bind the sign-in to the real site, so a relayed prompt does not work. Administrators are the highest-value targets, so they are the first accounts to move to these methods.

Users need a registered FIDO2 security key, Windows Hello for Business or a certificate before the policy is enabled for them, otherwise they are locked out. Roll out in report-only mode and keep emergency access accounts excluded.

Only emergency access accounts listed in [EmergencyAccessAccounts](https://maester.dev/docs/configuration/emergency-access-accounts) are accepted as exclusions, and a condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, select **Directory roles** and add the administrative roles. Exclude your emergency access accounts.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Grant**, select **Grant access** and **Require authentication strength**, then choose **Phishing-resistant MFA**.
6. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Require phishing-resistant multifactor authentication for administrators](https://learn.microsoft.com/entra/identity/conditional-access/policy-admin-phish-resistant-mfa)
* [Conditional Access authentication strength](https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.5](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

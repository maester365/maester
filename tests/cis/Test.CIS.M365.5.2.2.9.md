An enabled Conditional Access policy requires a compliant or hybrid joined device for all users and all cloud apps.

A stolen password or session token is far less useful when sign-in is limited to devices that your organisation manages and that meet its security baseline. Unmanaged devices are the usual source of malware that steals tokens.

This is a high-impact control: personal and partner devices lose access unless you provide an alternative such as browser-only access with session controls. Enrol devices in Microsoft Intune and define compliance policies before enabling the policy, and use report-only mode first.

Only emergency access accounts listed in [EmergencyAccessAccounts](https://maester.dev/docs/configuration/emergency-access-accounts) are accepted as exclusions, and a condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts and any service accounts that cannot use a managed device.
4. Under **Target resources**, select **All resources (formerly All cloud apps)**.
5. Under **Grant**, select **Grant access**, then **Require device to be marked as compliant** and optionally **Require Microsoft Entra hybrid joined device**. Choose **Require one of the selected controls**.
6. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Require compliant or hybrid joined devices with Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-compliance)
* [Require a compliant device in Conditional Access](https://learn.microsoft.com/intune/intune-service/protect/create-conditional-access-intune)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.9](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

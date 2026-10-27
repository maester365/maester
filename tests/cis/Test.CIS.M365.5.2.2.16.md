An enabled Conditional Access policy requires token protection for Exchange Online, SharePoint Online and Microsoft Teams on Windows desktop clients.

Session tokens are bearer tokens: whoever holds one can use it. Token protection binds a sign-in token to the device it was issued to, so a token copied by malware or a proxy does not work from another machine.

The capability is limited to supported Windows clients and to Exchange Online, SharePoint Online and Teams, and incompatible apps are blocked. The benchmark requires a user scope other than **None**. Check the sign-in logs in report-only mode to see which users and apps would be affected before enforcing.

User and group exclusions are not evaluated by this test. Application exclusions are also not evaluated when the policy targets all apps; verify exclusions are documented and reviewed annually. A condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include a non-empty user scope; the benchmark requires this field to be other than **None**.
4. Under **Target resources**, select **Select resources** and add **Office 365 Exchange Online**, **Office 365 SharePoint Online** and **Microsoft Teams Services**.
5. Under **Conditions** > **Device platforms**, include **Windows**. Under **Client apps**, select **Mobile apps and desktop clients** only.
6. Under **Session**, select **Require token protection for sign-in sessions**.
7. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Conditional Access: token protection](https://learn.microsoft.com/entra/identity/conditional-access/concept-token-protection)
* [Configure token protection](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-session)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.16](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

An enabled Conditional Access policy requires a compliant device when users register or change their security information. A hybrid-joined device may optionally be allowed as an alternative.

An attacker who has a password and can register their own authentication method controls the account from then on. Limiting registration to managed devices stops that persistence step from an unmanaged machine.

The policy applies to the register security information user action rather than to apps. Users who need to register from a new device can use a temporary access pass from a managed device or the office network.

User and group exclusions are not evaluated by this test. Application exclusions are also not evaluated when the policy targets all apps; verify exclusions are documented and reviewed annually. A condition that narrows the policy is reported unless the check is about that condition.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Conditional Access** > [**Policies**](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies) and select **New policy**.
3. Under **Users**, include **All users**. Exclude your emergency access accounts.
4. Under **Target resources**, select **User actions** and then **Register security information**.
5. Under **Grant**, select **Grant access**, then **Require device to be marked as compliant** and optionally **Require Microsoft Entra hybrid joined device**. Choose **Require one of the selected controls**.
6. Set **Enable policy** to **On** (use **Report-only** first to measure the impact) and select **Create**.

#### Related links

* [Microsoft Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Conditional Access policy to secure security information registration](https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-security-info-registration)
* [Conditional Access: user actions](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-cloud-apps#user-actions)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.2.2.10](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%

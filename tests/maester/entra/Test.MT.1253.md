At least one enabled Conditional Access policy should require risk remediation for all users when user risk is high.

Microsoft Entra ID Protection raises a user's risk when it sees signs that the account is compromised, such as leaked credentials, password spray or an anomalous token. A user risk policy with the **Require risk remediation** grant control lets users fix that risk themselves, and Microsoft Entra ID Protection picks the remediation flow that fits the risk and the user's authentication method:

* **Password-based users** perform a secure password change after MFA, and their previous sessions are revoked.
* **Passwordless users** have their sessions revoked and must sign in again.
* **An attacker-added device** is disabled so that it can no longer get tokens.

The older **Require password change** control only works for users who sign in with a password, so it leaves passwordless users without a way to remediate the risk themselves. When you select **Require risk remediation**, Conditional Access also applies **Require authentication strength** and **Sign-in frequency - Every time**, so the user signs in again with a strong method after the sessions are revoked.

This check passes when an enabled policy includes **All users**, targets **All resources**, covers the **High** user risk level and requires risk remediation. Raise the `MinimumUserRiskLevel` parameter to `medium` or `low` if your policy must cover those levels as well. Users must be registered for MFA before they can remediate.

The policy may exclude only your emergency access accounts and groups. Maester takes them from the `EmergencyAccessAccounts` setting; a configured entry that cannot be resolved makes the check report an error. Without the setting, a user or group that is excluded from every Conditional Access policy (at least two) is taken as emergency access, as in MT.1005. Any other user, group or directory role exclusion disqualifies the policy, even when it includes **All users**. Risk remediation is not supported for guest and external users, so excluding **Guest or external users** is allowed; individual guest accounts or guest groups are not. Make sure emergency access accounts are excluded; MT.1005 checks that.

#### Remediation action

1. In **Entra ID**, navigate to **Conditional Access** > **[Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)**.
2. Select **New policy**, or open the Microsoft-managed risk remediation policy if your tenant has one.
3. Under **Users**, include **All users** and exclude your emergency access accounts. List them in `EmergencyAccessAccounts` in `maester-config.json`. Remove other user, group and role exclusions; to leave out guests, exclude **Guest or external users** instead of individual accounts.
4. Under **Target resources**, include **All resources (formerly 'All cloud apps')**.
5. Under **Conditions** > **User risk**, set **Configure** to **Yes** and select **High**.
6. Under **Grant**, select **Grant access** and **Require risk remediation**. **Require authentication strength** and **Sign-in frequency - Every time** are selected automatically.
7. Review the impact in **Report-only** mode, then set **Enable policy** to **On** and click **Save**.
8. If an existing policy requires **Require password change** for user risk, replace it with this policy.

#### Related links

* [Entra admin center - Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)
* [Require remediation for risky users](https://learn.microsoft.com/entra/identity/conditional-access/policy-risk-based-user#require-risk-remediation)
* [Require risk remediation control](https://learn.microsoft.com/entra/id-protection/concept-identity-protection-policies#require-risk-remediation-control)
* [Remediate risks and unblock users](https://learn.microsoft.com/entra/id-protection/howto-identity-protection-remediate-unblock)
* [Microsoft-managed Conditional Access policies](https://learn.microsoft.com/entra/identity/conditional-access/managed-policies)

<!--- Results --->
%TestResult%

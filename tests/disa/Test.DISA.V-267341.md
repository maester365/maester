An enabled Conditional Access policy requires multifactor authentication for all users, including everyone who signs in to Intune. (DISA Microsoft Intune MDM Service Desktop STIG, V-267341, CAT II).

Intune sign-ins are handled by Microsoft Entra ID, so multifactor authentication for Intune users is a Conditional Access policy for all users.

This test runs [CIS.M365.5.2.2.2](https://maester.dev/docs/tests/CIS.M365.5.2.2.2), which checks for an enabled Conditional Access policy that requires MFA for all users.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **Entra ID** > **Conditional Access** > **[Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)**.
2. Create a policy (or use the **Require multifactor authentication for all users** template) that includes **All users** and **All resources** and grants access only with **Require multifactor authentication** or an authentication strength.
3. Exclude only your emergency access accounts, and document each exclusion with your authorizing official.
4. Set **Enable policy** to **On** and select **Save**.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop STIG: V-267341](https://cyber.trackr.live/stig/Intune_Service_Desktop/1/1/V-267341)
* [Require multifactor authentication for all users](https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-mfa-strength)

<!--- Results --->
%TestResult%

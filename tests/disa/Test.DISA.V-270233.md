An enabled Conditional Access policy requires multifactor authentication for all users. (DISA Microsoft Entra ID STIG, V-270233, CAT I).

A password alone is stolen by phishing, spray or reuse every day. Multifactor authentication for every user is the main control against those attacks, which is why DISA rates this rule CAT I.

DISA's check looks for an enabled Conditional Access policy that includes all users and requires MFA, with every exclusion documented with the authorizing official. This test runs [CIS.M365.5.2.2.2](https://maester.dev/docs/tests/CIS.M365.5.2.2.2), which checks that policy. Documenting the exclusions is up to you.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **Entra ID** > **Conditional Access** > **[Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)**.
2. Create a policy (or use the **Require multifactor authentication for all users** template) that includes **All users** and **All resources** and grants access only with **Require multifactor authentication** or an authentication strength.
3. Exclude only your emergency access accounts, and document each exclusion with your authorizing official.
4. Set **Enable policy** to **On** and select **Save**.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270233](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270233)
* [Require multifactor authentication for all users](https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-mfa-strength)

<!--- Results --->
%TestResult%

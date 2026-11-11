Microsoft Entra password protection enforces a custom banned password list that holds entries. (DISA Microsoft Entra ID STIG, V-270475, CAT II).

Users pick passwords from what is around them: the organization's name, products and places. A custom banned password list stops those words, on top of the global list Microsoft maintains.

DISA's check requires **Enforce custom list** set to **Yes** and a list that is not empty. This test runs [CIS.M365.5.2.3.2](https://maester.dev/docs/tests/CIS.M365.5.2.3.2), which checks both.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **Entra ID** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)** > **Password protection**.
2. Set **Enforce custom list** to **Yes** and add terms specific to your organization to **Custom banned password list**.
3. Select **Save**.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270475](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270475)
* [Eliminate bad passwords using Microsoft Entra Password Protection](https://learn.microsoft.com/entra/identity/authentication/concept-password-ban-bad)

<!--- Results --->
%TestResult%

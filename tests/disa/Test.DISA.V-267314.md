Microsoft Entra smart lockout, which protects Intune sign-ins, locks an account after three failed sign-ins for at least 15 minutes. (DISA Microsoft Intune MDM Service Desktop STIG, V-267314, CAT II).

Intune sign-ins are handled by Microsoft Entra ID, so the lockout rule is checked there. A low threshold with a long lockout limits online password guessing.

This test runs the same check as [CIS.M365.5.2.3.8](https://maester.dev/docs/tests/CIS.M365.5.2.3.8) with DISA's values: a lockout threshold of 3 or fewer and a lockout duration of at least 900 seconds.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **Entra ID** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)** > **Password protection**.
2. Set **Lockout threshold** to **3** and **Lockout duration in seconds** to **900** or more.
3. Select **Save**.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop STIG: V-267314](https://cyber.trackr.live/stig/Intune_Service_Desktop/1/1/V-267314)
* [Protect user accounts from attacks with Microsoft Entra smart lockout](https://learn.microsoft.com/entra/identity/authentication/howto-password-smart-lockout)

<!--- Results --->
%TestResult%

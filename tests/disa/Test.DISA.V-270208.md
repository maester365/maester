Microsoft Entra smart lockout locks an account after three failed sign-ins, for at least 15 minutes. (DISA Microsoft Entra ID STIG, V-270208, CAT II).

Online password guessing is cheap. A low lockout threshold with a long lockout duration limits how many passwords an attacker can try against each account.

This test runs the same check as [CIS.M365.5.2.3.8](https://maester.dev/docs/tests/CIS.M365.5.2.3.8) with DISA's values: a lockout threshold of 3 or fewer (`MaximumLockoutThreshold`) and a lockout duration of at least 900 seconds (`MinimumLockoutDurationSeconds`). CIS allows a threshold of 10 and does not check the duration. The Microsoft defaults (10 attempts, 60 seconds) fail.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **Entra ID** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)** > **Password protection**.
2. Set **Lockout threshold** to **3** and **Lockout duration in seconds** to **900** or more.
3. Select **Save**.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270208](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270208)
* [Protect user accounts from attacks with Microsoft Entra smart lockout](https://learn.microsoft.com/entra/identity/authentication/howto-password-smart-lockout)

<!--- Results --->
%TestResult%

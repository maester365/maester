User accounts, except for break glass accounts, are protected by fixed or risk-based lockout mechanisms aligned to a maximum of five failed logon attempts, with either indefinite or automated lockout durations (ISM-1403, Guidelines for system access).

Online password guessing is cheap: an attacker who can try ten passwords per account before a lockout gets ten chances at every account in the tenant. Microsoft Entra smart lockout counts failed sign-ins per account, locks the account for the lockout duration when the threshold is reached, and counts familiar and unfamiliar locations separately so that a user at their usual desk is not locked out by an attacker elsewhere.

This test runs the same check as [CIS.M365.5.2.3.8](https://maester.dev/docs/tests/CIS.M365.5.2.3.8) with ASD's maximum: the lockout threshold must be 5 or fewer (the `MaximumLockoutThreshold` parameter), where CIS allows 10. The Microsoft default of 10 fails. The ASD Blueprint for Secure Cloud sets a threshold of 5 and a lockout duration of 60 seconds.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **Entra ID** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)** > **Password protection**.
2. Set **Lockout threshold** to **5** and **Lockout duration in seconds** to at least **60**.
3. Select **Save**.

#### Related links

* [ISM Guidelines for system access: User account lockouts](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/ism/cyber-security-guidelines/guidelines-system-access)
* [ASD Blueprint for Secure Cloud: Password protection](https://blueprint.asd.gov.au/configuration/entra-id/protection/authentication-methods/password-protection/)
* [Protect user accounts from attacks with Microsoft Entra smart lockout](https://learn.microsoft.com/entra/identity/authentication/howto-password-smart-lockout)

<!--- Results --->
%TestResult%

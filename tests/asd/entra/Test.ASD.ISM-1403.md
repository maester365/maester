User accounts, except for break glass accounts, are protected by fixed or risk-based lockout mechanisms aligned to a maximum of five failed logon attempts (ISM-1403, Guidelines for system access).

Online password guessing is cheap: an attacker who can try ten passwords per account before a lockout gets ten chances at every account in the tenant. Microsoft Entra smart lockout counts failed sign-ins per account, locks the account for the lockout duration when the threshold is reached, and keeps counting familiar and unfamiliar locations separately so that a user at their usual desk is not locked out by an attacker elsewhere. This check reads the tenant's Password Rule Settings and passes when the lockout threshold is set explicitly to 5 or fewer (the `MaximumFailedAttempts` parameter). The Microsoft default of 10 fails. Break glass accounts are covered by smart lockout as well; keep their passwords long and random rather than excluding them.

#### Remediation action

1. In **Microsoft Entra admin center**, go to **Protection** > **[Authentication methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/PasswordProtection)** > **Password protection**.
2. Set **Lockout threshold** to **5** and **Lockout duration in seconds** to at least **60**.
3. Click **Save**.

#### Related links

* [ISM Guidelines for system access: User account lockouts](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/ism/cyber-security-guidelines/guidelines-system-access)
* [Protect user accounts from attacks with Microsoft Entra smart lockout](https://learn.microsoft.com/entra/identity/authentication/howto-password-smart-lockout)

<!--- Results --->
%TestResult%

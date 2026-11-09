The `PASSWORD_NOT_REQUIRED` user flag weakens credential requirements; it does not itself establish that a password is blank. Both enabled and disabled accounts are shown.

#### Control Type

**Detective**

#### Security Recommendation

Investigate both enabled and disabled accounts with `PASSWORD_NOT_REQUIRED`, set appropriate credentials and remove the setting after dependency review.

#### How the Test Works

The test identifies the password-not-required account-control flag. The flag alone does not establish whether a password is blank.

#### Related Tests

- **AD-USER-07 — All users should require Kerberos pre-authentication** — `Test-MtAdUserNoPreAuthCount` — Reviews pre-authentication exposure.
- **AD-USER-04 — User accounts should not allow reversible password encryption** — `Test-MtAdUserReversibleEncryptionCount` — Reviews reversible encryption configuration.

#### Remediation action
1. Review application dependencies, set a strong credential and clear the flag in [AD account settings](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).

<!--- Results --->
%TestResult%

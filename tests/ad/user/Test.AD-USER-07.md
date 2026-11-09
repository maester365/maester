Disabling Kerberos pre-authentication permits AS-REP roasting: an attacker can request crackable material without the password.

#### Control Type

**Detective**

#### Security Recommendation

Require Kerberos pre-authentication for affected accounts after confirming legacy dependencies, and rotate credentials where exposure warrants it.

#### How the Test Works

The test flags user accounts with the no-pre-authentication account-control bit; it does not establish whether their credentials were attacked.

#### Related Tests

- **AD-USER-06 — No user should require DES-only Kerberos keys** — `Test-MtAdUserKerberosDesOnlyCount` — Reviews weak Kerberos-key configuration.
- **AD-USER-09 — No user should have PasswordNotRequired set** — `Test-MtAdUserPasswordNotRequiredCount` — Reviews password-requirement flags.

#### Remediation action
1. Confirm dependencies and enable Kerberos pre-authentication on affected [AD user accounts](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Rotate exposed credentials according to incident-response policy.

<!--- Results --->
%TestResult%

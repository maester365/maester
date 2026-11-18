DES-only user Kerberos keys weaken encryption and expose authentication material to offline attack.

#### Control Type

**Detective**

#### Security Recommendation

Remove DES-only requirements after testing dependent applications; use supported stronger Kerberos encryption types.

#### How the Test Works

The test identifies user accounts with the DES-only Kerberos account-control setting; it does not measure the encryption used by every ticket.

#### Related Tests

- **AD-USER-07 — All users should require Kerberos pre-authentication** — `Test-MtAdUserNoPreAuthCount` — Reviews another Kerberos account-control setting.
- **AD-USER-04 — User accounts should not allow reversible password encryption** — `Test-MtAdUserReversibleEncryptionCount` — Reviews reversible encryption settings.

#### Remediation action
1. Identify legacy applications requiring DES with their owners.
2. Migrate to modern Kerberos encryption and clear the DES-only setting in [AD account settings](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-security-identifiers).

<!--- Results --->
%TestResult%

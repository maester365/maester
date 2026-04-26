#### Test-MtAdUserBuiltInAdminPasswordAgeDetails

#### Why This Test Matters

Highly privileged accounts with old passwords are prime targets for password spraying, credential theft, and persistence. Reviewing password age for built-in administrator style accounts helps validate that sensitive credentials are rotated appropriately.

- **Credential risk reduction**: Long-lived privileged passwords increase exposure.
- **Control validation**: Supports verification of password rotation practices.
- **Exception tracking**: Highlights accounts with non-expiring privileged credentials.

#### Security Recommendation

- Rotate passwords for privileged accounts on a defined schedule.
- Avoid non-expiring passwords on privileged identities wherever possible.
- Review break-glass or emergency accounts separately with compensating controls.

#### How the Test Works

This test lists built-in administrator style accounts and reports `PasswordLastSet`, calculated password age in days, and `PasswordNeverExpires` state.

#### Related Tests

- `Test-MtAdUserBuiltInAdminCount`
- `Test-MtAdUserBuiltInAdminLastLogonDetails`

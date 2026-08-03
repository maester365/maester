#### Test-MtAdUserReversibleEncryptionCount

#### Why This Test Matters

Reversible password encryption is effectively equivalent to storing passwords in a decryptable form. Accounts configured this way create serious exposure if the directory or credential material is compromised.

#### Security Recommendation

Disable reversible password encryption unless it is required for a documented legacy dependency that cannot be modernized immediately. Remediate those dependencies as a priority.

#### How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState` and counts accounts with reversible-encryption-style indicators. It checks explicit reversible encryption properties when available and falls back to the relevant `userAccountControl` flag.

#### Related Tests

- `Test-MtAdUserKerberosDesOnlyCount`
- `Test-MtAdUserPasswordNotRequiredCount`
- `Test-MtAdUserNoPreAuthCount`

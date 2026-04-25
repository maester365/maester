# Test-MtAdUserPasswordNotRequiredCount

## Why This Test Matters

Accounts that do not require passwords are a severe security weakness. Even if rarely used, they represent a misconfiguration that can undermine core authentication protections.

## Security Recommendation

Investigate every account with `PasswordNotRequired` set. Require passwords, rotate credentials, and validate that no workflow depends on this unsafe configuration.

## How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState` and counts accounts where `PasswordNotRequired = $true`. The output shows the total count and percentage of affected users.

## Related Tests

- `Test-MtAdUserPasswordNeverExpiresCount`
- `Test-MtAdUserNoPreAuthCount`
- `Test-MtAdUserReversibleEncryptionCount`

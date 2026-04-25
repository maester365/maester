# Test-MtAdUserPasswordNeverExpiresCount

## Why This Test Matters

Passwords that never expire reduce credential hygiene and increase the blast radius of password theft. While some service accounts may require non-expiring credentials, they should be rare, controlled, and closely monitored.

## Security Recommendation

Minimize the use of non-expiring passwords. Where legacy constraints require them, migrate to managed service accounts, vaulting, or other compensating controls.

## How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState`, filters to enabled users, and counts accounts where `PasswordNeverExpires = $true`. The output includes the count and percentage relative to enabled users.

## Related Tests

- `Test-MtAdUserDormantEnabledCount`
- `Test-MtAdUserPasswordNotRequiredCount`
- `Test-MtAdUserNeverLoggedInCount`

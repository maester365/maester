# Test-MtAdUserDisabledCount

## Why This Test Matters

Disabled user accounts are expected during offboarding, investigations, and staged deprovisioning. Tracking their volume helps identify stale objects that should be deleted, reduces directory clutter, and supports lifecycle governance.

## Security Recommendation

Review disabled user accounts regularly and remove accounts that no longer need to exist. For retained accounts, document the business reason and expected retention period.

## How the Test Works

This test retrieves cached Active Directory user data from `Get-MtADDomainState` and counts user objects where `Enabled = $false`. The result includes total, enabled, and disabled user counts plus the disabled percentage.

## Related Tests

- `Test-MtAdUserDormantEnabledCount`
- `Test-MtAdUserNeverLoggedInCount`
- `Test-MtAdUserPasswordNotRequiredCount`

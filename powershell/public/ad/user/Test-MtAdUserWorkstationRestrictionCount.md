# Test-MtAdUserWorkstationRestrictionCount

## Why This Test Matters

Restricting where a user can log on can reduce exposure for privileged, administrative, or sensitive accounts. Measuring how often workstation restrictions are used helps assess adoption of this hardening control.

## Security Recommendation

Consider applying workstation restrictions to privileged and high-value accounts where operationally feasible. Review configured restrictions periodically to ensure they remain accurate.

## How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState` and counts accounts where `LogonWorkstations` is populated.

## Related Tests

- `Test-MtAdUserDelegationAllowedCount`
- `Test-MtAdUserDormantEnabledCount`
- `Test-MtAdUserNeverLoggedInCount`

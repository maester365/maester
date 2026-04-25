# Test-MtAdUserDelegationAllowedCount

## Why This Test Matters

Delegation-capable user accounts can impersonate users to downstream services. If these accounts are over-privileged or poorly protected, they can become valuable pivot points for privilege escalation and lateral movement.

## Security Recommendation

Limit delegation to only the accounts that need it, prefer constrained models, and protect delegated accounts with strong authentication, tiering, and monitoring.

## How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState` and counts accounts where `TrustedForDelegation` or `TrustedToAuthForDelegation` is enabled. The results break out delegation types and show the overall count.

## Related Tests

- `Test-MtAdUserNoPreAuthCount`
- `Test-MtAdUserKerberosDesOnlyCount`
- `Test-MtAdUserPasswordNeverExpiresCount`

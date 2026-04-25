# Test-MtAdUserDelegationConfiguredCount

## Why This Test Matters

Delegation on user accounts can be especially risky because user identities are often easier to misuse than computer accounts. Service accounts configured for delegation can become powerful lateral movement pivots.

- **Lateral movement risk**: Delegation can expand the blast radius of compromise.
- **Privilege abuse**: User-based services with delegation deserve special scrutiny.
- **Exposure tracking**: Supports routine review of delegation-enabled identities.

## Security Recommendation

- Minimize delegation on user accounts.
- Prefer modern and least-privileged service identity patterns.
- Review all delegation-enabled users for valid business justification.
- Prioritize removal of unnecessary unconstrained delegation.

## How the Test Works

This test counts user accounts with either `TrustedForDelegation` or `TrustedToAuthForDelegation` enabled and breaks out how many have each flag.

## Related Tests

- `Test-MtAdUserDelegationDetails`
- `Test-MtAdUserKnownServiceAccountDetails`

# Test-MtAdUserHoneyPotCount

## Why This Test Matters

Accounts with names that look especially attractive to attackers can be useful as deliberate decoys, but they can also reflect risky naming practices or forgotten identities that warrant review.

- **Threat detection support**: Decoy-style names can be monitored for malicious interaction.
- **Naming hygiene**: Identifies user names likely to draw attacker attention.
- **Access review**: Confirms whether these accounts are intentional and documented.

## Security Recommendation

- Document whether identified accounts are real users, service accounts, or deception assets.
- Apply strong monitoring to any deliberate honey pot or lure account.
- Disable or clean up misleading accounts that no longer serve a purpose.

## How the Test Works

This test counts non-system user accounts whose names match attractive terms such as `admin`, `root`, `test`, `backup`, or `sql`.

## Related Tests

- `Test-MtAdUserHoneyPotDetails`
- `Test-MtAdUserBuiltInAdminEnabledDetails`

# Test-MtAdUserBuiltInAdminCount

## Why This Test Matters

Built-in and critical administrator-related accounts are among the most sensitive identities in Active Directory. Attackers frequently target these accounts because they provide durable, high-impact access.

- **High-value targets**: RID 500 accounts are especially attractive to attackers.
- **Detection support**: Helps validate whether renamed administrator accounts still exist.
- **Tier-0 review**: Critical system objects warrant extra monitoring and protection.

## Security Recommendation

- Minimize use of built-in administrator accounts.
- Monitor all RID 500 activity closely.
- Apply strong credential protection and privileged access controls.
- Review critical system accounts for expected state and usage.

## How the Test Works

This test counts user objects whose SID ends in `-500` or are marked as `isCriticalSystemObject`.

## Related Tests

- `Test-MtAdUserBuiltInAdminEnabledDetails`
- `Test-MtAdUserBuiltInAdminLastLogonDetails`
- `Test-MtAdUserBuiltInAdminPasswordAgeDetails`

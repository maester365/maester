# Test-MtAdDaclPrivilegedAllowAceCount

## Why This Test Matters

Allow ACEs that grant `GenericAll`, `WriteDacl`, `WriteOwner`, or `ExtendedRight` can enable high-impact control over Active Directory objects. These permissions are commonly involved in privilege escalation and persistence paths.

- **GenericAll**: Grants broad control over the object.
- **WriteDacl / WriteOwner**: Enables permission tampering or ownership takeover.
- **ExtendedRight**: May allow sensitive control-access operations depending on object type.

## Security Recommendation

Limit privileged rights to tightly controlled administrative groups. Investigate unexpected identities or objects that accumulate these permissions.

## How the Test Works

This test reads `DaclEntries` from `Get-MtADDomainState`, filters to allow ACEs, and counts entries where `ActiveDirectoryRights` includes `GenericAll`, `WriteDacl`, `WriteOwner`, or `ExtendedRight`.

## Related Tests

- `Test-MtAdDaclPrivilegedAllowAceDetails`
- `Test-MtAdDaclPrivilegedExtendedRightCount`
- `Test-MtAdDaclDistinctIdentityCount`

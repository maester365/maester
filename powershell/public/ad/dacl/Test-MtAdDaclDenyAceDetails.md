# Test-MtAdDaclDenyAceDetails

## Why This Test Matters

When deny ACEs exist, administrators need to know exactly which identities are denied on which objects. Grouping deny ACEs by object and identity makes it easier to review intent and spot concentrated or unusual deny patterns.

- **Maps denied principals to specific objects**
- **Supports delegated access reviews**
- **Helps identify concentrated deny patterns** that deserve validation

## Security Recommendation

Review each deny ACE grouping to confirm it reflects an intentional control. Focus especially on privileged objects, administrative groups, and OUs used for delegation.

## How the Test Works

This test retrieves `$adState.DaclEntries`, filters entries where `AccessControlType` contains `Deny`, groups results by `ObjectDN` and `IdentityReference`, and reports the count of deny ACEs for each combination.

## Related Tests

- `Test-MtAdDaclDenyAceCount`
- `Test-MtAdDaclConflictObjectDetails`
- `Test-MtAdDaclOuObjectCount`

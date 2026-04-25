# Test-MtAdDaclConflictObjectDetails

## Why This Test Matters

High-level counts are useful, but remediation usually requires object-level detail. This test helps administrators pinpoint each conflict object present in the DACL dataset and understand how many ACEs are attached to it.

- **Shows the exact conflict objects** found in DACL analysis
- **Supports cleanup validation** by exposing object class and DN
- **Quantifies ACE volume** on each conflict object

## Security Recommendation

Review each listed conflict object, confirm why it exists, and determine whether it is still needed. If an object is obsolete, validate dependencies and permissions before cleanup.

## How the Test Works

This test retrieves `$adState.DaclEntries`, filters for entries whose `ObjectDN` contains `CNF`, groups them by object distinguished name, and returns each object with its class and ACE count.

## Related Tests

- `Test-MtAdDaclConflictObjectCount`
- `Test-MtAdDaclDenyAceDetails`
- `Test-MtAdDaclOuObjectCount`

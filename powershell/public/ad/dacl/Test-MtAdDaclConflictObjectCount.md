#### Test-MtAdDaclConflictObjectCount

#### Why This Test Matters

Conflict objects with `CNF` markers typically originate from replication or naming conflicts. Even when old, they can indicate historical AD hygiene issues and should be understood before being ignored.

- **Surfaces replication-conflict remnants** in DACL analysis
- **Helps identify cleanup candidates**
- **Provides context** for unexpected objects appearing in permission reviews

#### Security Recommendation

Investigate conflict objects and confirm whether they are expected remnants, still referenced, or safe to clean up. Review their permissions before remediation to understand any delegated access that may still exist.

#### How the Test Works

This test retrieves `$adState.DaclEntries`, searches for `CNF` within `ObjectDN`, deduplicates matching distinguished names, and reports the number of unique conflict objects and associated DACL entries.

#### Related Tests

- `Test-MtAdDaclConflictObjectDetails`
- `Test-MtAdDaclDistinctObjectCount`
- `Test-MtAdDaclDenyAceDetails`

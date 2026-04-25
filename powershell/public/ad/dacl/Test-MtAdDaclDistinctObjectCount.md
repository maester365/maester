# Test-MtAdDaclDistinctObjectCount

## Why This Test Matters

Knowing how many distinct Active Directory objects are represented in the collected DACL dataset helps establish the scope of permission analysis.

- **Measures DACL coverage** across collected directory objects
- **Provides a baseline** for comparing later DACL metrics
- **Helps validate collection breadth** when reviewing AD permission visibility

## Security Recommendation

Use this count as a baseline metric when reviewing DACL analysis. Unexpectedly low counts can indicate collection gaps, limited visibility, or an unexpectedly small review scope.

## How the Test Works

This test retrieves `$adState.DaclEntries`, extracts the `ObjectDN` value from each entry, deduplicates the object list, and reports the total number of unique objects with DACL entries.

## Related Tests

- `Test-MtAdDaclOuObjectCount`
- `Test-MtAdDaclConflictObjectCount`
- `Test-MtAdDaclDenyAceCount`

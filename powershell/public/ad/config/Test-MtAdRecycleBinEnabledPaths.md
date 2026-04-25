# Test-MtAdRecycleBinEnabledPaths

## Why This Test Matters
**Recycle Bin enabled paths** indicate which naming contexts/partitions have AD’s Recycle Bin functionality turned on. This matters because the Recycle Bin is a major control for limiting damage from:

- **Accidental deletions** (including bulk removal mistakes)
- **Insider misuse** where deletion is used to cover tracks
- **Operational failures** where objects must be restored quickly to resume secure workflows

Without Recycle Bin enabled for the right partitions, deleted objects may be **irrecoverable** once tombstone/purge timelines are exceeded.

## Security Recommendation
- Enable Recycle Bin for all partitions that store security-critical objects (for example, identity data in domains/NCs you manage).
- Ensure your recovery playbooks explicitly reference Recycle Bin vs. tombstone recovery.
- Monitor for unexpected changes to enabled partitions and investigate immediately.

## How the Test Works
This test enumerates AD partitions/paths and reports which ones have Recycle Bin enabled, giving administrators direct visibility into recoverability coverage.

## Related Tests
- `Test-MtAdRecycleBinStatus` - Confirms overall Recycle Bin functionality state.

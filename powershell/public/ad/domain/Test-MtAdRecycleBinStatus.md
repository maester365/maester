# Test-MtAdRecycleBinStatus

## Why This Test Matters

The Active Directory Recycle Bin provides significant advantages over traditional tombstone reanimation:

- **Complete Object Recovery**: Restores all object attributes, group memberships, and links
- **Simplified Recovery**: No need to restore from backup for accidental deletions
- **Reduced Downtime**: Faster recovery of critical objects
- **Attribute Preservation**: Unlike tombstone reanimation, all attributes are preserved

**Requirements**:
- Forest functional level of Windows Server 2008 R2 or higher
- Must be explicitly enabled (not enabled by default)

## Security Recommendation

**Enable the Recycle Bin** if your forest functional level supports it:

```powershell
Enable-ADOptionalFeature -Identity "Recycle Bin Feature" -Scope ForestOrConfigurationSet -Target "yourforest.com"
```

**Important Considerations**:
- **Irreversible**: Once enabled, the Recycle Bin cannot be disabled
- **Database Size**: Increases AD database size due to preserved objects
- **Tombstone Lifetime**: Objects are retained for the tombstone lifetime period
- **Planning**: Ensure adequate disk space and backup strategies

## How the Test Works

This test checks the optional features in Active Directory to determine if the Recycle Bin Feature is enabled and reports its status.

## Related Tests

- `Test-MtAdTombstoneLifetime` - Retrieves the tombstone lifetime (affects Recycle Bin retention)
- `Test-MtAdForestFunctionalLevel` - Retrieves the forest functional level (required for Recycle Bin)

#### Test-MtAdTombstoneLifetime

#### Why This Test Matters

The tombstone lifetime determines how long deleted Active Directory objects are retained in the database before being permanently removed:

- **Accidental Deletion Recovery**: Longer lifetimes provide more time to recover accidentally deleted objects
- **Replication Stability**: Ensures deleted objects replicate to all DCs before being purged
- **Backup Recovery**: Aligns with backup retention strategies for directory recovery
- **Compliance**: Some regulations require specific retention periods for directory data

**Default Values**:
- **180 days**: Default for forests created on Windows Server 2003 SP1 and later
- **60 days**: Default for older forests (Windows 2000/2003 RTM)

#### Security Recommendation

- **Minimum 180 Days**: Maintain at least 180 days for adequate recovery time
- **Align with Backups**: Ensure tombstone lifetime matches or exceeds backup retention
- **Monitor Changes**: Track any modifications to this critical setting
- **Document**: Record the current setting and any business requirements

To modify the tombstone lifetime:
```powershell
$configurationNC = (Get-ADRootDSE).configurationNamingContext
Set-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,$configurationNC" -Replace @{tombstoneLifetime=180}
```

#### How the Test Works

This test retrieves the tombstone lifetime from the Directory Service configuration object and reports the current value along with recommendations.

#### Related Tests

- `Test-MtAdRecycleBinStatus` - Checks if the AD Recycle Bin is enabled
- `Test-MtAdForestFunctionalLevel` - Retrieves the forest functional level (required for Recycle Bin)

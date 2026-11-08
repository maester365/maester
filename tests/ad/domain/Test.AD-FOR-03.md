The tombstone lifetime determines how long deleted Active Directory objects are retained in the database before being permanently removed:

- **Accidental Deletion Recovery**: Longer lifetimes provide more time to recover accidentally deleted objects
- **Replication Stability**: Ensures deleted objects replicate to all DCs before being purged
- **Backup Recovery**: Aligns with backup retention strategies for directory recovery
- **Compliance**: Some regulations require specific retention periods for directory data

When `tombstoneLifetime` is **not set**, Active Directory uses an effective **60 days** even in an upgraded forest. Newer forests can have an explicitly configured 180-day value; this check distinguishes the stored attribute from the effective value.

#### Control Type

**Preventive**

#### Security Recommendation

- Choose a retention period appropriate to the recovery and replication window. Do not assume an unset attribute means 180 days.
- **Align with Backups**: Ensure tombstone lifetime matches or exceeds backup retention
- **Monitor Changes**: Track any modifications to this critical setting
- **Document**: Record the current setting and any business requirements

To modify the tombstone lifetime:
```powershell
$configurationNC = (Get-ADRootDSE).configurationNamingContext
Set-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,$configurationNC" -Replace @{tombstoneLifetime=180}
```

#### How the Test Works

This test retrieves the tombstone lifetime from the Directory Service configuration object and reports both the configured attribute and effective value. It is an inventory check, not a pass/fail threshold for retention length. AD-CFG-01 was consolidated into this check.

#### Coverage crosswalk

Former AD-CFG-01 is covered here. The single primary `Feature` remains `directory-configuration`; forest context is linked through AD-FOR-01 and AD-FOR-04 rather than a second feature.

#### Related links

- [Microsoft ADTS: tombstone lifetime and unset-attribute default](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/1887de08-2a9e-4694-95e2-898cde411180)

#### Related Tests

- `Test-MtAdRecycleBinStatus` - Checks if the AD Recycle Bin is enabled
- `Test-MtAdForestFunctionalLevel` - Retrieves the forest functional level (required for Recycle Bin)

<!--- Results --->
%TestResult%

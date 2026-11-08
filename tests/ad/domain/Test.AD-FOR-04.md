The Active Directory Recycle Bin provides significant advantages over traditional tombstone reanimation:

- **Complete Object Recovery**: Restores all object attributes, group memberships, and links
- **Simplified Recovery**: No need to restore from backup for accidental deletions
- **Reduced Downtime**: Faster recovery of critical objects
- **Attribute Preservation**: Unlike tombstone reanimation, all attributes are preserved

**Requirements**:
- Forest functional level of Windows Server 2008 R2 or higher
- Must be explicitly enabled (not enabled by default)

#### Control Type

**Preventive**

#### Security Recommendation

**Enable the Recycle Bin** if your forest functional level supports it:

```powershell
Enable-ADOptionalFeature -Identity "Recycle Bin Feature" -Scope ForestOrConfigurationSet -Target "yourforest.com"
```

**Important Considerations**:
- **Irreversible**: Once enabled, the Recycle Bin cannot be disabled
- **Database Size**: Increases AD database size due to preserved objects
- **Deleted-object retention**: Recoverability follows `msDS-deletedObjectLifetime`, which defaults to `tombstoneLifetime` when not set; later recycled-object retention is a separate phase
- **Planning**: Ensure adequate disk space and backup strategies

#### How the Test Works

This test fails if the Recycle Bin Feature exists but is not enabled, passes if enabled, and errors if the feature cannot be uniquely identified or its status was not retrieved. It does not treat successful enumeration as evidence of protection. AD-CFG-05 was consolidated into this check; AD-FEAT-01 inventories all optional features and their enabled scopes separately.

#### Remediation action

Verify functional-level prerequisites and retention/storage requirements, then enable the Recycle Bin with the approved administrative identity. Do not enable it as a reversible experiment. Confirm the feature's enabled scope and test the organization's recovery procedure separately.

#### Related links

- [Microsoft: Active Directory Recycle Bin](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-recycle-bin)

#### Related Tests

- **AD-FOR-03 — Tombstone lifetime should be retrievable** — `Test-MtAdTombstoneLifetime` — Inventories tombstone lifetime.
- **AD-FOR-01 — Forest functional level meets the highest supported common level** — `Test-MtAdForestFunctionalLevel` — Reviews the forest functional level.

<!--- Results --->
%TestResult%

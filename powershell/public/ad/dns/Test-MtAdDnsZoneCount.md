#### Test-MtAdDnsZoneCount

#### Why This Test Matters

DNS zones are the primary organizational units for DNS data. Understanding how many zones contain resource records helps assess:

- **Infrastructure complexity**: More zones indicate a more complex DNS environment
- **Administrative boundaries**: Zones often represent different administrative domains
- **Service distribution**: Multiple zones may indicate delegated or distributed services
- **Security posture**: Unused or empty zones may represent configuration drift

#### Security Recommendation

Regularly audit DNS zones to ensure they are all necessary and properly configured. Remove unused zones and verify that zone delegation follows your organization's security policies.

#### How the Test Works

This test retrieves all DNS zones and counts those that contain resource records. It provides:
- Total number of DNS zones
- Count of zones with records
- Count of empty zones

#### Related Tests

- `Test-MtAdDnsEmptyZoneCount` - Identifies zones with no records
- `Test-MtAdDnsZonesWithOnlySoaNs` - Finds zones with only default records

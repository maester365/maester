#### Test-MtAdDnsZoneRecordDetails

#### Why This Test Matters

Detailed record distribution across zones helps identify:

- **High-traffic zones**: Zones with many records may be critical infrastructure
- **Underutilized zones**: Zones with few records may be candidates for consolidation
- **Potential issues**: Unusual record distributions may indicate problems
- **Resource planning**: Understanding record counts helps capacity planning

#### Security Recommendation

Review zones with unusually high record counts for:
- Stale or orphaned records that should be removed
- Unauthorized records that may indicate compromise
- Configuration errors causing excessive record creation

#### How the Test Works

This test provides a detailed breakdown of record counts per zone, including the most common record types in each zone.

#### Related Tests

- `Test-MtAdDnsZoneCount` - Counts zones with records
- `Test-MtAdDnsDynamicRecordCount` - Analyzes dynamic vs static records

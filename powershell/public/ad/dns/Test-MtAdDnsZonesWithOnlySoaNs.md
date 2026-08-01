#### Test-MtAdDnsZonesWithOnlySoaNs

#### Why This Test Matters

DNS zones that contain only SOA (Start of Authority) and NS (Name Server) records are essentially placeholder zones. These zones:

- **May indicate incomplete configuration**: Zones created but never populated with actual records
- **Could represent abandoned infrastructure**: Services that were planned but never deployed
- **Might be unnecessary**: Adding complexity without providing value
- **Can cause confusion**: Administrators may assume these zones are actively used

#### Security Recommendation

Review zones with only SOA/NS records and either:
- Populate them with necessary resource records if they serve a purpose
- Delete them if they are no longer needed
- Document their purpose if they are intentionally placeholder zones

#### How the Test Works

This test identifies DNS zones that contain only SOA and NS records, with no A, AAAA, CNAME, MX, SRV, or other record types.

#### Related Tests

- `Test-MtAdDnsZoneCount` - Counts all zones with records
- `Test-MtAdDnsEmptyZoneCount` - Finds zones with zero records

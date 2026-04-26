#### Test-MtAdDnsZonesWithRecordsCount

#### Why This Test Matters

Zones with non-default records (beyond SOA and NS) are actively used for DNS resolution. Understanding which zones contain actual service records helps:

- **Identify active services**: Zones with records indicate active DNS services
- **Assess attack surface**: More active zones mean more potential targets
- **Plan maintenance**: Active zones require more careful change management
- **Audit compliance**: Verify only authorized zones are in use

#### Security Recommendation

Regularly review zones with non-default records to ensure they are all necessary and properly secured. Verify that zone contents align with authorized services and applications.

#### How the Test Works

This test identifies DNS zones that contain records beyond the default SOA and NS records, excluding special zones like RootDNSServers and reverse lookup zones.

#### Related Tests

- `Test-MtAdDnsZoneCount` - Counts all zones with records
- `Test-MtAdDnsZonesWithOnlySoaNs` - Finds zones with only default records

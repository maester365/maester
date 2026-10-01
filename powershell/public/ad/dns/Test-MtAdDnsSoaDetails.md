#### Test-MtAdDnsSoaDetails

#### Why This Test Matters

SOA (Start of Authority) records contain critical zone management parameters:

- **Primary server**: The authoritative source for zone data
- **Responsible party**: Contact information for zone administration
- **Serial number**: Used for zone transfer synchronization
- **Refresh/Retry/Expire**: Controls secondary server behavior

Incorrect SOA settings can cause:
- Zone transfer failures
- DNS resolution delays
- Inconsistent data across servers
- Administrative confusion

#### Security Recommendation

- Ensure primary server values point to valid, secured DNS servers
- Use appropriate contact information that reaches responsible administrators
- Monitor serial numbers for unexpected changes
- Set appropriate TTL values to balance performance and flexibility

#### How the Test Works

This test retrieves SOA record details for each zone, including primary server, responsible party, serial number, and timing parameters.

#### Related Tests

- `Test-MtAdDnsZonesWithOnlySoaNs` - Identifies zones with only SOA/NS records

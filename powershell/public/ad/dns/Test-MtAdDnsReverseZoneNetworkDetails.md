#### Test-MtAdDnsReverseZoneNetworkDetails

#### Why This Test Matters

Detailed information about networks with reverse lookup zones enables:

- **Network inventory**: Complete list of networks with reverse DNS
- **Security auditing**: Verification that only authorized networks are configured
- **Troubleshooting**: Quick identification of reverse DNS coverage
- **Documentation**: Accurate records of DNS infrastructure

Understanding which networks have reverse zones is essential for comprehensive DNS management.

#### Security Recommendation

Review reverse zone network details regularly:
- Verify all listed networks are authorized
- Ensure CIDR notation is appropriate for each network
- Document the purpose of each reverse zone
- Remove reverse zones for decommissioned networks

#### How the Test Works

This test provides detailed information about each network with a reverse lookup zone, including:
- Network address
- CIDR notation
- Reverse zone name
- Zone type

#### Related Tests

- `Test-MtAdDnsReverseZoneCount` - Counts reverse lookup zones
- `Test-MtAdDnsReverseZoneNetworkCount` - Counts distinct networks

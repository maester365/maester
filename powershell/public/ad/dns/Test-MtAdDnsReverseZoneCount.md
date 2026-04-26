#### Test-MtAdDnsReverseZoneCount

#### Why This Test Matters

Reverse lookup zones enable IP-to-name resolution (PTR records) and are essential for:

- **Security auditing**: Identifying systems by IP address
- **Network troubleshooting**: Resolving IPs to hostnames
- **Application functionality**: Many services require reverse DNS
- **Compliance**: Some regulations require reverse DNS configuration

The number of reverse zones indicates network coverage for reverse resolution.

#### Security Recommendation

- Maintain reverse zones for all internal networks
- Ensure reverse records are kept synchronized with forward records
- Protect reverse zones from unauthorized modification
- Monitor for unexpected changes to reverse zones

#### How the Test Works

This test counts reverse lookup zones (zones ending in .in-addr.arpa for IPv4 and .ip6.arpa for IPv6).

#### Related Tests

- `Test-MtAdDnsReverseZoneNetworkCount` - Counts distinct networks with reverse zones
- `Test-MtAdDnsReverseZoneNetworkDetails` - Provides detailed network information

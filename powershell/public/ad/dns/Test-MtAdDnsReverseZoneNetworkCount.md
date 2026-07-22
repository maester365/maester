#### Test-MtAdDnsReverseZoneNetworkCount

#### Why This Test Matters

Understanding how many distinct networks have reverse lookup zones helps:

- **Network coverage assessment**: Ensure all internal networks have reverse DNS
- **IP space management**: Understand which networks are configured for reverse resolution
- **Security monitoring**: Identify gaps in reverse DNS coverage
- **Compliance verification**: Meet requirements for reverse DNS configuration

Each reverse zone represents a network segment that can be resolved from IP to hostname.

#### Security Recommendation

- Maintain reverse zones for all production networks
- Ensure consistent coverage across the organization
- Document any networks intentionally without reverse zones
- Monitor for unauthorized reverse zone creation

#### How the Test Works

This test analyzes reverse lookup zone names to extract and count unique network addresses.

#### Related Tests

- `Test-MtAdDnsReverseZoneCount` - Counts reverse lookup zones
- `Test-MtAdDnsReverseZoneNetworkDetails` - Provides detailed network information

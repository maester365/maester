# Test-MtAdSubnetIpv6CatchAllCount

## Why This Test Matters

Overly broad IPv6 subnets can cause similar issues to IPv4 catch-all subnets:

- **Authentication inefficiency**: Clients may authenticate to distant DCs
- **Suboptimal routing**: Site boundaries don't reflect actual topology
- **Management complexity**: Difficult to track client locations
- **Security concerns**: Reduced granularity in access controls

IPv6 /48 prefixes or larger are considered catch-all ranges.

## Security Recommendation

- Use appropriately-sized IPv6 subnets (typically /64 for client networks)
- Align IPv6 subnet boundaries with physical locations
- Document IPv6 subnet allocation scheme
- Review IPv6 subnet definitions regularly

## How the Test Works

This test identifies IPv6 subnets with overly broad prefixes (/48 or smaller).

## Related Tests

- `Test-MtAdSubnetIpv6Count` - Counts IPv6 subnets
- `Test-MtAdSubnetCatchAllCount` - Identifies IPv4 catch-all subnets
- `Test-MtAdSubnetTotalCount` - Counts total subnets

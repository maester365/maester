#### Test-MtAdSubnetIpv6Count

#### Why This Test Matters

IPv6 subnet configuration is important for:

- **Future-proofing**: IPv6 adoption continues to grow
- **Dual-stack environments**: Supporting both IPv4 and IPv6 clients
- **Compliance**: Meeting IPv6 readiness requirements
- **Modern networks**: Many modern networks are IPv6-first

Understanding IPv6 subnet deployment helps assess the organization's IPv6 readiness.

#### Security Recommendation

- Define IPv6 subnets for all locations where IPv6 is deployed
- Ensure IPv6 subnets mirror IPv4 site topology
- Document IPv6 addressing scheme
- Plan for IPv6-only client support

#### How the Test Works

This test counts subnets that use IPv6 address format (containing colons).

#### Related Tests

- `Test-MtAdSubnetIpv6CatchAllCount` - Identifies overly broad IPv6 subnets
- `Test-MtAdSubnetTotalCount` - Counts total subnets
- `Test-MtAdSubnetSiteAssociationCount` - Counts sites with subnets

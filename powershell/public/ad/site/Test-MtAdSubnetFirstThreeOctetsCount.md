#### Test-MtAdSubnetFirstThreeOctetsCount

#### Why This Test Matters

Analyzing /24 network distribution provides:

- **Subnet granularity**: Understanding the typical subnet size in use
- **Location mapping**: Each /24 often represents a specific location or VLAN
- **Capacity insight**: How many discrete network segments exist
- **Documentation**: Detailed network topology information

/24 networks (254 hosts) are the most common subnet size for client networks.

#### Security Recommendation

- Document the purpose of each /24 network
- Align /24 boundaries with physical locations or security zones
- Plan /24 allocation to support VLAN and location requirements
- Review /24 utilization for optimization opportunities

#### How the Test Works

This test extracts the first three octets from all IPv4 subnets and counts the distinct /24 networks.

#### Related Tests

- `Test-MtAdSubnetFirstOctetCount` - Analyzes first octets
- `Test-MtAdSubnetFirstTwoOctetsCount` - Analyzes /16 networks
- `Test-MtAdSubnetTotalCount` - Counts total subnets

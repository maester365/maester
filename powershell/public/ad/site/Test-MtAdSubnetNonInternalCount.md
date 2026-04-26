#### Test-MtAdSubnetNonInternalCount

#### Why This Test Matters

Using public IP addresses internally can cause:

- **Routing conflicts**: If public IPs are also used on the internet
- **Security risks**: Internal resources may be exposed
- **Compliance issues**: Violation of IP address allocation standards
- **Connectivity problems**: NAT and firewall complications

RFC1918 private ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) should be used for internal networks.

#### Security Recommendation

- Use RFC1918 private IP ranges for internal networks
- If public IPs are required internally, ensure proper isolation
- Document any exceptions with business justification
- Review subnet assignments for compliance

#### How the Test Works

This test identifies subnets that use public IP address ranges outside of RFC1918 private ranges.

#### Related Tests

- `Test-MtAdSubnetNonInternalDetails` - Lists public IP subnets
- `Test-MtAdSubnetTotalCount` - Counts total subnets
- `Test-MtAdSubnetCatchAllCount` - Identifies overly broad subnets

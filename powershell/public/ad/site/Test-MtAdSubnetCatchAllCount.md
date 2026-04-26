#### Test-MtAdSubnetCatchAllCount

#### Why This Test Matters

Catch-all subnets (overly broad IP ranges) can cause:

- **Authentication inefficiency**: Clients may authenticate to distant DCs
- **WAN congestion**: Unnecessary cross-site authentication traffic
- **Security concerns**: Difficult to track and audit client locations
- **Operational confusion**: Site boundaries don't reflect actual topology

Common catch-all subnets include 10.0.0.0/8, 172.16.0.0/12, and 192.168.0.0/16.

#### Security Recommendation

- Replace catch-all subnets with specific, appropriately-sized subnets
- Use /24 or smaller subnets for most locations
- Document exceptions where catch-all subnets are intentionally used
- Review subnet definitions during network planning

#### How the Test Works

This test identifies subnets with overly broad CIDR notation that could encompass multiple physical locations.

#### Related Tests

- `Test-MtAdSubnetNonInternalCount` - Identifies public IP subnets
- `Test-MtAdSubnetTotalCount` - Counts total subnets
- `Test-MtAdSiteWithoutSubnetCount` - Identifies sites without subnets

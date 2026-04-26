#### Test-MtAdSubnetNonInternalDetails

#### Why This Test Matters

Detailed information about public IP subnet usage helps:

- **Identify misconfigurations**: Find subnets that should use private ranges
- **Assess security posture**: Evaluate exposure of internal resources
- **Plan remediation**: Prioritize subnet renumbering efforts
- **Document exceptions**: Record legitimate uses of public IPs

Each public IP subnet should be reviewed for proper isolation and business justification.

#### Security Recommendation

For each public IP subnet:
1. Verify if the use is intentional and justified
2. Ensure proper network isolation is in place
3. Document the business requirement
4. Plan migration to private ranges if appropriate
5. Review firewall and NAT configurations

#### How the Test Works

This test retrieves all subnets, identifies those using public IP ranges, and lists them with their site associations and descriptions.

#### Related Tests

- `Test-MtAdSubnetNonInternalCount` - Counts public IP subnets
- `Test-MtAdSubnetTotalCount` - Counts total subnets
- `Test-MtAdSubnetSiteAssociationCount` - Counts sites with subnets

#### Test-MtAdSubnetWithoutSiteCount

#### Why This Test Matters

Subnets without site associations (orphaned subnets) can cause:

- **Client mislocation**: Computers with these IPs cannot determine their site
- **Authentication inefficiency**: Clients may authenticate to distant DCs
- **Configuration drift**: Orphaned subnets may indicate incomplete cleanup
- **Operational confusion**: Unclear which locations these subnets serve

Orphaned subnets should be either assigned to sites or removed.

#### Security Recommendation

- Assign orphaned subnets to appropriate sites
- Remove subnets that are no longer in use
- Review subnet assignments during network changes
- Document the purpose and location of all subnets

#### How the Test Works

This test identifies subnets that have no site association (SiteObject is null).

#### Related Tests

- `Test-MtAdSiteWithoutSubnetCount` - Identifies sites without subnets
- `Test-MtAdSubnetSiteAssociationCount` - Counts sites with subnets
- `Test-MtAdSubnetTotalCount` - Counts total subnets

#### Test-MtAdSiteWithoutSubnetCount

#### Why This Test Matters

Sites without subnet associations cannot be used for client site assignment:

- **Authentication inefficiency**: Clients may authenticate to distant DCs
- **Replication issues**: Site topology may not reflect actual network boundaries
- **Configuration gaps**: Sites may have been created incompletely
- **Client confusion**: Computers cannot determine their site membership

Every site that should be used for client location must have at least one subnet assigned.

#### Security Recommendation

- Assign appropriate subnets to all production sites
- Remove sites that are no longer needed
- Ensure subnet assignments accurately reflect network boundaries
- Review site-subnet mappings during network changes

#### How the Test Works

This test analyzes subnet-to-site associations to identify sites that have no subnets assigned to them.

#### Related Tests

- `Test-MtAdSiteWithoutSubnetDetails` - Lists sites without subnet associations
- `Test-MtAdSubnetWithoutSiteCount` - Identifies orphaned subnets
- `Test-MtAdSiteTotalCount` - Counts total sites in the domain

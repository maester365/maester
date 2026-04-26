#### Test-MtAdSiteWithoutSubnetDetails

#### Why This Test Matters

Sites without subnets represent incomplete configuration that can lead to:

- **Client mislocation**: Computers may authenticate to incorrect DCs
- **Replication inefficiency**: Site topology doesn't guide replication paths
- **Service location failures**: Clients cannot locate local services
- **Administrative confusion**: Sites exist but cannot be used

Identifying and resolving these configuration gaps ensures the site topology functions correctly.

#### Security Recommendation

For each site without subnets:
1. Determine if the site represents an active location
2. If active, assign appropriate subnet(s) to the site
3. If inactive, consider deleting the site
4. Document the purpose of each site
5. Validate that subnet assignments match actual network topology

#### How the Test Works

This test retrieves all sites and subnets, identifies sites with no subnet associations, and lists them with their descriptions.

#### Related Tests

- `Test-MtAdSiteWithoutSubnetCount` - Counts sites without subnets
- `Test-MtAdSubnetWithoutSiteCount` - Counts orphaned subnets
- `Test-MtAdSiteTotalCount` - Counts total sites in the domain

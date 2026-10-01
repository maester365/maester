#### Test-MtAdSubnetTotalCount

#### Why This Test Matters

Subnets are the foundation of Active Directory site assignment:

- **Client location**: Subnets determine which site a client belongs to
- **Authentication routing**: Directs clients to the nearest domain controller
- **Service discovery**: Helps clients find local services
- **Network segmentation**: Reflects the physical network topology

Understanding the number and distribution of subnets helps ensure proper client site assignment across the organization.

#### Security Recommendation

- Maintain accurate subnet definitions that reflect the physical network
- Review subnet assignments during network changes
- Remove obsolete subnets to prevent misconfiguration
- Ensure all IP ranges in use are properly defined

#### How the Test Works

This test retrieves all Active Directory subnets using `Get-ADReplicationSubnet` and counts the total number of subnets configured.

#### Related Tests

- `Test-MtAdSubnetSiteAssociationCount` - Counts sites with subnet associations
- `Test-MtAdSubnetWithoutSiteCount` - Identifies orphaned subnets
- `Test-MtAdSiteTotalCount` - Counts total sites in the domain

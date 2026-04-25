# Test-MtAdSiteWithoutDcCount

## Why This Test Matters

Sites without domain controllers may indicate:

- **Authentication delays**: Clients in these sites must authenticate across the WAN to another site
- **Single points of failure**: If the WAN link fails, clients cannot authenticate
- **Incomplete deployment**: Sites may have been created but DCs were never deployed
- **Resource gaps**: Branch offices may lack local domain controller presence

Sites without DCs should be carefully evaluated to ensure they represent intentional design decisions rather than configuration gaps.

## Security Recommendation

For sites without domain controllers:
- Consider deploying RODCs (Read-Only Domain Controllers) in branch offices
- Ensure WAN links are reliable and have adequate bandwidth
- Document the business justification for sites without local DCs
- Monitor authentication traffic from these sites

## How the Test Works

This test compares the list of sites with domain controllers against all sites in the domain to identify sites that have no DC presence.

## Related Tests

- `Test-MtAdSiteWithoutDcDetails` - Lists the specific sites without DCs
- `Test-MtAdSiteTotalCount` - Counts total sites in the domain
- `Test-MtAdDcSiteCoverageCount` - Analyzes DC distribution across sites

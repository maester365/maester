# Test-MtAdDcNonGlobalCatalogCount

## Why This Test Matters

Global Catalogs (GCs) maintain a partial replica of all objects in the Active Directory forest, enabling:

- **Forest-wide searches**: Users can search for objects across all domains in the forest
- **Universal group membership caching**: Required for authentication when universal groups are used
- **Efficient authentication**: Users can be authenticated even when their home domain's DC is unavailable

In a **single-domain environment**, all domain controllers should be Global Catalogs for optimal performance and redundancy. There's no downside to making all DCs GCs when there's only one domain.

In a **multi-domain forest**, proper Global Catalog placement is critical:
- Each site should have at least one GC for optimal authentication performance
- Too few GCs can cause authentication delays and failures
- Too many GCs can increase replication traffic

## Security Recommendation

1. **Single-domain forests**: Configure all DCs as Global Catalogs
2. **Multi-domain forests**: Ensure each site has at least one GC, preferably in the same site as the users
3. **Monitor GC health**: Regularly verify GCs are functioning properly
4. **Plan for GC failure**: Ensure redundant GC coverage for business-critical sites
5. **Universal group considerations**: If not using universal groups, GC requirements may be reduced, but GCs still provide benefits for directory searches

## How the Test Works

This test retrieves all domain controllers and identifies which are configured as Global Catalogs. The test reports:

- Total number of domain controllers
- Number of DCs configured as Global Catalogs
- Number of DCs not configured as Global Catalogs
- Names of non-GC DCs (if any exist)
- Forest domain count to provide context for the configuration

The test provides different guidance based on whether the forest is single-domain or multi-domain.

## Related Tests

- `Test-MtAdDcReadOnlyCount` - Analyzes RODC deployment
- `Test-MtAdDcSiteCoverageCount` - Analyzes DC distribution across sites
- `Test-MtAdForestDomainCount` - Determines the number of domains in the forest

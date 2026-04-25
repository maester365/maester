# Test-MtAdGroupUniversalCount

## Why This Test Matters

Universal groups play a specific role in multi-domain Active Directory environments:

- **Cross-domain flexibility**: Can contain users and groups from any domain in the forest
- **Forest-wide access**: Can be used for access control across the entire forest
- **Global Catalog storage**: Group membership is stored in the Global Catalog
- **Replication impact**: Membership changes trigger forest-wide replication
- **Multi-domain consolidation**: Useful for nesting global groups from multiple domains

High numbers of universal groups may indicate a complex multi-domain environment or potential replication optimization opportunities.

## Security Recommendation

Use universal groups strategically:
1. Minimize membership changes to universal groups to reduce replication traffic
2. Use universal groups primarily in multi-domain environments where cross-domain access is needed
3. Nest global groups (containing users) into universal groups rather than adding users directly
4. Consider the replication impact when designing universal group structure
5. Document the forest-wide access each universal group provides
6. In single-domain environments, prefer global and domain local groups

## How the Test Works

This test examines all group objects and identifies those where:
- The `GroupScope` property equals "Universal"
- These groups can contain members from any domain in the forest
- Membership is stored in the Global Catalog

The test provides counts and percentages to understand the distribution of group scopes in your environment.

## Related Tests

- `Test-MtAdGroupDistributionCount` - Counts distribution groups (email-only)
- `Test-MtAdGroupSecurityCount` - Counts security groups by category
- `Test-MtAdGroupDomainLocalCount` - Counts domain local scope groups
- `Test-MtAdGroupGlobalCount` - Counts global scope groups

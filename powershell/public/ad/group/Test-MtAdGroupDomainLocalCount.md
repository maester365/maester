# Test-MtAdGroupDomainLocalCount

## Why This Test Matters

Domain local groups have specific characteristics that affect your security architecture:

- **Domain boundary restriction**: Can only be used to assign permissions to resources within the same domain
- **Flexible membership**: Can contain users, global groups, and universal groups from any domain in the forest
- **Resource access control**: Typically used to grant access to specific resources (file shares, printers, applications)
- **AGDLP/AGUDLP strategy**: Part of Microsoft's recommended group nesting strategy (Accounts go into Global groups, which go into Domain Local groups for Permissions)

High numbers of domain local groups may indicate resource-specific access patterns.

## Security Recommendation

Follow Microsoft's AGDLP/AGUDLP best practices:
1. Use domain local groups to assign permissions to resources in their domain
2. Nest global or universal groups (containing users) into domain local groups
3. Avoid adding individual users directly to domain local groups
4. Name domain local groups according to their resource access purpose (e.g., "DL-FileServer01-Modify")
5. Document all resources each domain local group provides access to

## How the Test Works

This test examines all group objects and identifies those where:
- The `GroupScope` property equals "DomainLocal"
- These groups can only assign permissions to resources in their own domain

The test provides counts and percentages to understand the distribution of group scopes in your environment.

## Related Tests

- `Test-MtAdGroupDistributionCount` - Counts distribution groups (email-only)
- `Test-MtAdGroupSecurityCount` - Counts security groups by category
- `Test-MtAdGroupGlobalCount` - Counts global scope groups
- `Test-MtAdGroupUniversalCount` - Counts universal scope groups

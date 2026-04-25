# Test-MtAdGroupGlobalCount

## Why This Test Matters

Global groups are the most commonly used group type for organizing users in Active Directory:

- **User organization**: Used to organize users by role, department, or function
- **Forest-wide usage**: Can be used across the entire forest for access control
- **Domain replication**: Group membership only replicates within the domain, reducing replication traffic
- **AGDLP/AGUDLP strategy**: Accounts are placed into Global groups as the first step in the recommended group nesting strategy

A high number of global groups typically indicates well-organized user role management.

## Security Recommendation

Optimize global group usage:
1. Use global groups to organize users by role, department, or business function
2. Keep global group membership relatively stable to minimize replication
3. Nest global groups into domain local or universal groups for resource access
4. Avoid assigning permissions directly to global groups—use them as user containers
5. Implement a naming convention that reflects the group's purpose (e.g., "G-Department-Finance")

## How the Test Works

This test examines all group objects and identifies those where:
- The `GroupScope` property equals "Global"
- These groups can contain users and other global groups from the same domain
- Membership changes only replicate within the domain

The test provides counts and percentages to understand the distribution of group scopes in your environment.

## Related Tests

- `Test-MtAdGroupDistributionCount` - Counts distribution groups (email-only)
- `Test-MtAdGroupSecurityCount` - Counts security groups by category
- `Test-MtAdGroupDomainLocalCount` - Counts domain local scope groups
- `Test-MtAdGroupUniversalCount` - Counts universal scope groups
